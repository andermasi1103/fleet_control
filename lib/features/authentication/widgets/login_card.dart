import 'package:flutter/material.dart';
import '../../../shared/widgets/app_card.dart';
import 'login_form.dart';
import 'login_header.dart';
import 'login_footer.dart';

class LoginCard extends StatelessWidget {
  const LoginCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: AppCard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                LoginHeader(),
                SizedBox(height: 32),
                LoginForm(),
                SizedBox(height: 24),
                LoginFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
