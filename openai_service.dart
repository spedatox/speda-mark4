import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Firebase ve Google Sign In için ek importlar
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Google Calendar API
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/googleapis_auth.dart';

// Local Notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Timezone
import 'package:timezone/timezone.dart' as tz;

// Speda ilgili kısımlar
import 'package:speda/screens/secrets.dart';
import 'package:speda/screens/persona.dart';

/// Basit mesaj modeli
class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});
}

class OpenAIService {
  final String googleApiKey = GoogleApiKey;
  final String searchEngineId = googleSearchCx;
  final String openAIApiKey = openAIAPIKey;

  String _model = 'gpt-4o-mini';
  void changeModel(String newModel) => _model = newModel;

  final List<ChatMessage> messagesHistory = [];

  GoogleSignInAccount? _googleUser;
  AuthClient? _googleAuthClient;
  String? _accessToken;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  OpenAIService() {
    messagesHistory.add(ChatMessage(role: 'system', content: personaContent));
  }

  Future<void> initNotifications() async {
    final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings();
    final initSet = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSet);
  }

  Future<String> chatGPTAPI(String userPrompt) async {
    final possibleCalendarResponse = await _handleCalendarCommands(userPrompt);
    if (possibleCalendarResponse != null && possibleCalendarResponse.isNotEmpty) {
      return possibleCalendarResponse;
    } else {
      return await _sendToChatGPT(userPrompt);
    }
  }

  Future<String> chatGPTWithImage(String textPrompt, String base64Image) async {
    final userPrompt =
        "Kullanıcıdan gelen metin: $textPrompt\n"
        "Base64 Image: $base64Image\n"
        "Lütfen bu resim ve metin hakkında detaylı veya uygun bir açıklama yap. "
        "Aynı zamanda metne dair soruları da cevapla.";

    final possibleCalendarResponse = await _handleCalendarCommands(textPrompt);
    if (possibleCalendarResponse != null && possibleCalendarResponse.isNotEmpty) {
      final calendarPart = possibleCalendarResponse;
      final imagePart = await _sendToChatGPT(userPrompt);
      return "$calendarPart\n\n$imagePart";
    } else {
      return await _sendToChatGPT(userPrompt);
    }
  }

  void clearMessages() {
    messagesHistory.clear();
    messagesHistory.add(ChatMessage(role: 'system', content: personaContent));
  }

  Future<String> _sendToChatGPT(String userContent) async {
    messagesHistory.add(ChatMessage(role: 'user', content: userContent));

    final List<Map<String, String>> messagesPayload = messagesHistory
        .map((msg) => {'role': msg.role, 'content': msg.content})
        .toList();

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $openAIApiKey',
        },
        body: jsonEncode({"model": _model, "messages": messagesPayload}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String assistantResponse = data['choices'][0]['message']['content'].trim();
        messagesHistory.add(ChatMessage(role: 'assistant', content: assistantResponse));
        return assistantResponse;
      } else {
        return 'OpenAI API Hatası: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'OpenAI Bağlantı Hatası: $e';
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'https://www.googleapis.com/auth/calendar'],
      );
      _googleUser = await googleSignIn.signIn();
      if (_googleUser == null) return null;

      final googleAuth = await _googleUser!.authentication;
      _accessToken = googleAuth.accessToken;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      _googleAuthClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          ['https://www.googleapis.com/auth/calendar'],
        ),
      );

      return userCredential;
    } catch (e) {
      debugPrint('Google Sign In Hatası: $e');
      return null;
    }
  }

  Future<List<gcal.CalendarListEntry>> listCalendars() async {
    if (_googleAuthClient == null) throw Exception("Önce Google ile giriş yapmalısınız.");
    final calendarApi = gcal.CalendarApi(_googleAuthClient!);
    final calendarList = await calendarApi.calendarList.list();
    return calendarList.items ?? [];
  }

  Future<List<gcal.Event>> listEvents(String calendarId) async {
    if (_googleAuthClient == null) throw Exception("Önce Google ile giriş yapmalısınız.");
    final calendarApi = gcal.CalendarApi(_googleAuthClient!);
    final events = await calendarApi.events.list(
      calendarId,
      maxResults: 50,
      singleEvents: true,
      orderBy: 'startTime',
      timeMin: DateTime.now().toUtc(),
    );
    return events.items ?? [];
  }

  Future<gcal.Event> createEvent({
    required String calendarId,
    required String summary,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (_googleAuthClient == null) throw Exception("Önce Google ile giriş yapmalısınız.");
    final calendarApi = gcal.CalendarApi(_googleAuthClient!);
    final event = gcal.Event(
      summary: summary,
      start: gcal.EventDateTime(dateTime: startTime.toUtc(), timeZone: "UTC"),
      end: gcal.EventDateTime(dateTime: endTime.toUtc(), timeZone: "UTC"),
    );
    return await calendarApi.events.insert(event, calendarId);
  }

  Future<void> deleteEvent(String calendarId, String eventId) async {
    if (_googleAuthClient == null) throw Exception("Önce Google ile giriş yapmalısınız.");
    final calendarApi = gcal.CalendarApi(_googleAuthClient!);
    await calendarApi.events.delete(calendarId, eventId);
  }

  Future<void> scheduleNotificationForEvent(gcal.Event event) async {
    if (event.start == null || event.start!.dateTime == null) return;
    final startTime = event.start!.dateTime!;
    final notificationTime = startTime.subtract(const Duration(minutes: 10));
    if (notificationTime.isBefore(DateTime.now())) return;

    final id = event.id.hashCode & 0x7fffffff;
    final androidDetails = AndroidNotificationDetails(
      'calendar_channel', 'Takvim Hatırlatıcı',
      channelDescription: 'Yaklaşan etkinlik bildirimleri',
      importance: Importance.max, priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails, iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.zonedSchedule(
      id, "Etkinlik Yaklaşıyor", event.summary ?? "Takvim etkinliğiniz başlamak üzere.",
      _convertToTZDateTime(notificationTime), notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  Future<String?> _handleCalendarCommands(String userPrompt) async {
    final addEventRegex = RegExp(r'\b(e?k?le|#AddEvent)\b', caseSensitive: false);
    final listEventRegex = RegExp(r'\b(listele|#Listele|#ListEvents)\b', caseSensitive: false);
    final summarizeRegex = RegExp(r'\b(özetle|#Özetle)\b', caseSensitive: false);

    if (_googleAuthClient == null) {
      if (listEventRegex.hasMatch(userPrompt) ||
          summarizeRegex.hasMatch(userPrompt) ||
          addEventRegex.hasMatch(userPrompt)) {
        return "Takvim işlemi için önce Google ile giriş yapmalısın.";
      }
      return null;
    }

    final dateRegexISO = RegExp(r'(\d{4}-\d{2}-\d{2})');
    DateTime? startDate;
    final isoMatch = dateRegexISO.firstMatch(userPrompt);
    if (isoMatch != null) {
      try { startDate = DateTime.parse(isoMatch.group(1)!); } catch (_) {}
    }
    startDate ??= DateTime.now();
    final endDate = startDate.add(const Duration(days: 1));

    if (addEventRegex.hasMatch(userPrompt)) {
      final splitted = userPrompt.split(RegExp(r'\b(e?k?le|#AddEvent)\b', caseSensitive: false));
      if (splitted.length > 1) {
        final eventName = splitted.last.trim();
        try {
          final newEvent = await createEvent(
            calendarId: "primary", summary: eventName,
            startTime: startDate, endTime: startDate.add(const Duration(hours: 1)),
          );
          return "Etkinlik eklendi: '${newEvent.summary}' (${startDate.toLocal()})";
        } catch (e) {
          return "Etkinlik eklenirken hata oluştu: $e";
        }
      }
      return "Etkinlik adını anlayamadım.";
    }

    if (listEventRegex.hasMatch(userPrompt)) {
      final events = await _fetchEventsBetween(startDate, endDate);
      if (events.isEmpty) return "Bu tarihte etkinlik yok.";
      String rawEventData = events.map((ev) =>
          "Etkinlik: ${ev.summary}, Başlangıç: ${ev.start?.dateTime?.toLocal()}").join('\n');
      return await _sendToChatGPT(
          "Aşağıdaki takvim etkinliklerini kullanıcıya doğal ve sohbet tarzında listele.\n$rawEventData");
    }

    if (summarizeRegex.hasMatch(userPrompt)) {
      final events = await _fetchEventsBetween(startDate, endDate);
      if (events.isEmpty) return "Özetlenecek etkinlik yok.";
      String rawEventData = events.map((ev) =>
          "Etkinlik: ${ev.summary}, Başlangıç: ${ev.start?.dateTime?.toLocal()}").join('\n');
      return await _sendToChatGPT(
          "Aşağıdaki takvim etkinliklerini kısaca özetle.\n$rawEventData");
    }

    return null;
  }

  Future<List<gcal.Event>> _fetchEventsBetween(DateTime start, DateTime end) async {
    final events = await listEvents("primary");
    return events.where((ev) {
      final st = ev.start?.dateTime;
      if (st == null) return false;
      return st.isAfter(start) && st.isBefore(end);
    }).toList();
  }

  Future<String> webSearchAPI(String query) async {
    final url = Uri.parse(
        'https://customsearch.googleapis.com/customsearch/v1?key=$googleApiKey&cx=$searchEngineId&q=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['items'] is List) {
          List<dynamic> items = data['items'];
          List<String> snippets = items
              .map((item) => item is Map<String, dynamic> && item['snippet'] is String
                  ? item['snippet'].toString() : "")
              .where((s) => s.isNotEmpty).toList();
          if (snippets.isEmpty) return "Arama sonuçları boş döndü.";
          String combinedResults = snippets.take(25).join(' ');
          return await _sendToChatGPT(
              "Bu bilgileri kullanarak kullanıcıya detaylı ve açıklayıcı bir özet ver: $combinedResults");
        }
        return "Yanıt formatı beklenenden farklı.";
      }
      return 'Google API Hatası: ${response.statusCode}';
    } catch (e) {
      return 'Google Web Arama Bağlantı Hatası: $e';
    }
  }
}
