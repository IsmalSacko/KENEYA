import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/utils/app_style.dart';
import '../common/utils/kcolors.dart';
import '../common/utils/kstrings.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController telephoneCtrl = TextEditingController();
  final TextEditingController pinCtrl = TextEditingController();
  bool _hidePin = true;

  @override
  void dispose() {
    telephoneCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      telephone: telephoneCtrl.text.trim(),
      pin: pinCtrl.text.trim(),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? AppText.kErrorLogin)),
      );
      return;
    }

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          AppText.kLoginTitle,
          style: appStyle(18, Kolors.kWhite, FontWeight.w600),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Kolors.kPrimary, Kolors.kBlue, Kolors.kPrimaryLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 620 : 460),
                child: Container(
                  padding: EdgeInsets.all(isDesktop ? 28 : 22),
                  decoration: BoxDecoration(
                    color: Kolors.kWhite.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: Kolors.kSecondaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/logo_keneya_plus_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppText.kAppName,
                          style: appStyle(28, Kolors.kDark, FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppText.kLoginSubtitle,
                          style: appStyle(14, Kolors.kGray, FontWeight.w500),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: telephoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: AppText.kTelephone,
                            hintText: AppText.kEnterTelephone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            filled: true,
                            fillColor: Kolors.kOffWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return AppText.kErrorEmptyFields;
                            if (text.length < 8) {
                              return 'Numero de telephone invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: _hidePin,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: AppText.kPassword,
                            hintText: 'Entrez votre PIN',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _hidePin = !_hidePin);
                              },
                              icon: Icon(
                                _hidePin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor: Kolors.kOffWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return AppText.kErrorEmptyFields;
                            if (text.length < 4) return 'PIN invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Kolors.kPrimary,
                              foregroundColor: Kolors.kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: auth.loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Kolors.kWhite,
                                    ),
                                  )
                                : Text(
                                    AppText.kLoginButton,
                                    style: appStyle(
                                      15,
                                      Kolors.kWhite,
                                      FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            AppText.kAppSlogan,
                            textAlign: TextAlign.center,
                            style: appStyle(12, Kolors.kGray, FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
