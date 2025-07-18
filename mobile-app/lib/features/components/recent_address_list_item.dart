import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class RecentAddressListItem extends StatefulWidget {
  final String address;
  final VoidCallback onTap;

  const RecentAddressListItem({
    super.key,
    required this.address,
    required this.onTap,
  });

  @override
  State<RecentAddressListItem> createState() => _RecentAddressListItemState();
}

class _RecentAddressListItemState extends State<RecentAddressListItem> {
  late Future<String> _humanReadableNameFuture;

  @override
  void initState() {
    super.initState();
    _humanReadableNameFuture = HumanReadableChecksumService()
        .getHumanReadableName(widget.address);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _humanReadableNameFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  'Loading name...',
                  style: TextStyle(
                    color: Color(0xFF16CECE),
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                );
              } else if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Text(
                  'Unknown Name',
                  style: TextStyle(
                    color: Color(0xFF16CECE),
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                );
              }
              return Text(
                snapshot.data!,
                style: const TextStyle(
                  color: Color(0xFF16CECE),
                  fontSize: 14,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            widget.address,
            style: TextStyle(
              color: Colors.white.useOpacity(0.60),
              fontSize: 11,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
