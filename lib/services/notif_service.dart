import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMensajeFondoControlador(RemoteMessage mensaje) async {
  await NotificationService.instance.configurarNotificaciones();
  await NotificationService.instance.muestraNotificacion(mensaje);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  
  final _messaging = FirebaseMessaging.instance; 
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  Future<void> inicializar() async {

    FirebaseMessaging.onBackgroundMessage(_firebaseMensajeFondoControlador);

    await _requestPermission();


    await _mensajeControlador();

    // final token = await _messaging.getToken();

    suscribirTema('ensambladores');

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
      'Canal importante',
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
      onDidReceiveBackgroundNotificationResponse: (details) {
        
        
      },
    );


    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> muestraNotificacion(RemoteMessage mensaje) async {
    RemoteNotification? notificacion = mensaje.notification;
    AndroidNotification? android = mensaje.notification?.android;
    if (notificacion != null && android != null) {
      await _localNotifications.show(
        notificacion.hashCode,
        notificacion.title,
        notificacion.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
             'Canal importante',
             'Notificaciones importantes',
             channelDescription:  'Este canal es usado para notificaciones importantes',
             importance: Importance.high,
             priority: Priority.high,
             icon: '@mipmap/ic_launcher',
            )
        )
      );
      
    }
  } 

  Future<void> _mensajeControlador() async{
    //foreground
    FirebaseMessaging.onMessage.listen((mensaje) { 
      muestraNotificacion(mensaje);
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