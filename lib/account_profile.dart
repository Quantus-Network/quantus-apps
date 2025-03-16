import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'substrate_service.dart';

class AccountProfilePage extends StatelessWidget {
  final String accountId;

  const AccountProfilePage({
    Key? key,
    required this.accountId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2D2D2D),
                      Color(0xFF6B46C1).withOpacity(0.3),
                    ],
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF6B46C1).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF9F7AEA),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Address',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                accountId,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: accountId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Address copied to clipboard')),
                        );
                      },
                      icon: Icon(Icons.copy),
                      label: Text('Copy Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6B46C1),
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Security',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Clear wallet data and start fresh',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Confirm Logout'),
                      content: Text(
                        'Are you sure you want to log out? This will delete all local wallet data. Make sure you have backed up your recovery phrase.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('Log Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await SubstrateService().logout();
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
