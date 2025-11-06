// ignore_for_file: use_build_context_synchronously

import 'package:sistema_rastreabilidad/componentes/my_botton.dart';
import 'package:sistema_rastreabilidad/componentes/my_textfield.dart';
import 'package:sistema_rastreabilidad/componentes/squeare_tile.dart';
import 'package:sistema_rastreabilidad/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void registrarse() async {
    if (!mounted) return; // Verificar si el widget está montado

    showDialog(
      context: context,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      if (passwordController.text == confirmPasswordController.text) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        showCustomSnackBar(
          context,
          'Contraseña no coinciden',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        showCustomSnackBar(
          context,
          'Usuario o contraseña incorrecta',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } else {
        showCustomSnackBar(
          context,
          e.message ?? 'Ocurrió un error al iniciar sesión',
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context,
        'Ocurrió un error al iniciar sesión: $e',
      );
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void showCustomSnackBar(BuildContext context, String message,
      {Color backgroundColor = Colors.black, Color textColor = Colors.white}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf6f6f6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'lib/images/logo-asia-rob.png',
                    height: 150,
                  ),
                  const SizedBox(width: 0),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'Registrar usuario',
                style: TextStyle(
                    color: Color(0xFF1e3a5d),
                    fontSize: 30,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              MyTextField(
                controller: emailController,
                hintText: 'Email',
                obscureText: false,
              ),
              const SizedBox(height: 30),
              MyTextField(
                controller: passwordController,
                hintText: 'Contraseña',
                obscureText: true,
              ),
              const SizedBox(height: 30),
              MyTextField(
                controller: confirmPasswordController,
                hintText: 'Confirmar Contraseña',
                obscureText: true,
              ),
              const SizedBox(height: 30),
              MyButton(
                text: "Registrarse",
                onTap: registrarse,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                      child: Divider(
                    thickness: 0.5,
                    color: Colors.grey[400],
                  )),
                  Text(
                    'O',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Expanded(
                      child: Divider(
                    thickness: 0.5,
                    color: Colors.grey[400],
                  ))
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SqueareTile(
                    onTap: () => AuthService().signInWithGoogle(),
                    imagePath: 'lib/images/google.png',
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ya tienes una cuenta?',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: const Text(
                      'Iniciar Sesion',
                      style: TextStyle(
                        color: Color(0xFF1e3a5d),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              )
            ]),
          ),
        ),
      ),
    );
  }
}
