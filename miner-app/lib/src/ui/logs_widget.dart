import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../services/log_stream_processor.dart';
import '../services/mining_orchestrator.dart';

class LogsWidget extends StatefulWidget {
  final MiningOrchestrator? orchestrator;
  final int maxLines;

  const LogsWidget({super.key, this.orchestrator, this.maxLines = 20000});

  @override
  State<LogsWidget> createState() => _LogsWidgetState();
}

class _LogsWidgetState extends State<LogsWidget> {
  final List<LogEntry> _logs = [];
  StreamSubscription<LogEntry>? _logsSubscription;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = false; // Default to false so users can investigate logs
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _setupLogsListener();
  }

  @override
  void didUpdateWidget(LogsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orchestrator != widget.orchestrator) {
      _setupLogsListener();
    }
  }

  void _setupLogsListener() {
    _logsSubscription?.cancel();
    _logs.clear();

    if (widget.orchestrator != null) {
      _logsSubscription = widget.orchestrator!.logsStream.listen((logEntry) {
        if (mounted) {
          setState(() {
            _logs.add(logEntry);
            // Keep only the last maxLines entries
            if (_logs.length > widget.maxLines) {
              _logs.removeRange(0, _logs.length - widget.maxLines);
            }
          });

          // Auto-scroll to bottom if enabled and not user-scrolling
          if (_autoScroll && !_isUserScrolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use jumpTo instead of animateTo to prevent jittering
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Color _getLogColor(String source) {
    switch (source) {
      case 'node':
        return Colors.blue;
      case 'node-error':
        return Colors.red;
      case 'miner':
        return Colors.green;
      case 'miner-error':
        return Colors.orange;
      // Legacy source names for compatibility
      case 'quantus-miner':
        return Colors.green;
      case 'quantus-miner-error':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header with controls
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.useOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Text('Live Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top, size: 20),
                  onPressed: _toggleAutoScroll,
                  tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
                ),
                IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: _clearLogs, tooltip: 'Clear logs'),
              ],
            ),
          ),

          // Logs display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs available\nStart the node to see live logs',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Track when user is actively scrolling
                        if (notification is ScrollStartNotification) {
                          _isUserScrolling = true;
                        } else if (notification is ScrollEndNotification) {
                          _isUserScrolling = false;
                          // Check if user scrolled to bottom - re-enable auto-scroll
                          if (_scrollController.hasClients) {
                            final isAtBottom =
                                _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50;
                            if (isAtBottom && !_autoScroll) {
                              // User scrolled to bottom, could re-enable auto-scroll
                            }
                          }
                        }
                        return false;
                      },
                      child: SelectionArea(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timestamp
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      log.timestamp.toIso8601String().substring(11, 19),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
                                    ),
                                  ),

                                  // Source indicator
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(right: 8, top: 2),
                                    decoration: BoxDecoration(color: _getLogColor(log.source), shape: BoxShape.circle),
                                  ),

                                  // Source label
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '[${log.source}]',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getLogColor(log.source),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // Log message
                                  Expanded(
                                    child: Text(
                                      log.message,
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),

          // Footer with log count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.useOpacity(0.05),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total logs: ${_logs.length}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (widget.orchestrator?.isMining ?? false)
                  const Text(
                    'Live',
                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                  )
                else
                  const Text('Not connected', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
