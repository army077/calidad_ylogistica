import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMensajeFondoControlador(RemoteMessage mensaje) async {
  await Firebase.initializeApp();
  await NotificationService.instance.configurarNotificaciones();
  await NotificationService.instance.muestraNotificacion(mensaje);
}

@pragma('vm:entry-point')
void _notificacionLocalEnSegundoPlano(NotificationResponse _) {}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  
  final _messaging = FirebaseMessaging.instance; 
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;
  static const _channelId = 'high_importance_channel';

  Future<void> inicializar() async {

    FirebaseMessaging.onBackgroundMessage(_firebaseMensajeFondoControlador);



    await _mensajeControlador();

    await configurarNotificaciones();
    await suscribirTema('operadores');

  }

  Future<void> _requestPermission() async {
    // final configuracion = await _messaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    //   provisional: true,
    //   announcement: true,
    //   carPlay: true,
    //   criticalAlert: true,
    // );

  }

  Future<void> configurarNotificaciones() async {

    if(_isFlutterLocalNotificationsInitialized){
      return;
    }
    //android
    const canal = AndroidNotificationChannel(
      _channelId,
      'Notificaciones importantes',
      description: 'Este canal es usado para importar notificaciones',
      importance: Importance.high
      );

    await _localNotifications
       .resolvePlatformSpecificImplementation
       <AndroidFlutterLocalNotificationsPlugin>()
       ?.createNotificationChannel(canal);

    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');


    final initializationSettings = const InitializationSettings(
      android: initializationSettingsAndroid
    );



    await _localNotifications.initialize(
       initializationSettings,
        onDidReceiveBackgroundNotificationResponse:
          _notificacionLocalEnSegundoPlano,
    );


    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> muestraNotificacion(RemoteMessage mensaje) async {
    final title = mensaje.notification?.title ??
        mensaje.data['title']?.toString() ??
        mensaje.data['titulo']?.toString();
    final body = mensaje.notification?.body ??
        mensaje.data['body']?.toString() ??
        mensaje.data['cuerpo']?.toString();

    if (title == null && body == null) return;

    await _localNotifications.show(
      mensaje.messageId?.hashCode ?? mensaje.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Notificaciones importantes',
          channelDescription: 'Avisos importantes de calidad y logística',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> _mensajeControlador() async{
    //foreground
    FirebaseMessaging.onMessage.listen((mensaje) async {
      await muestraNotificacion(mensaje);
    });


    //background
    FirebaseMessaging.onMessageOpenedApp.listen(_mensajeFondoControlador);


    //app abierta
    final mensajeInicial = await _messaging.getInitialMessage();
    if (mensajeInicial != null) {
      _mensajeFondoControlador(mensajeInicial);
    }
  }

  void _mensajeFondoControlador(RemoteMessage mensaje) {
    if (mensaje.data['type'] == 'chat') {
      //abrir prev_day
    }
  }

  Future<void> suscribirTema(String tema) async {
    await FirebaseMessaging.instance.subscribeToTopic(tema);
  }


}