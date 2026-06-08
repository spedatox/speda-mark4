import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:speda/screens/openai_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;

  const ChatScreen({Key? key, this.initialMessage}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final OpenAIService _openAIService = OpenAIService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  User? _currentUser;
  PlatformFile? _attachedFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _sendMessage(widget.initialMessage!);
    }
  }

  Future<void> _signIn() async {
    final credential = await _openAIService.signInWithGoogle();
    if (credential != null) {
      setState(() { _currentUser = credential.user; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? text]) async {
    final userText = text ?? _controller.text.trim();
    if (userText.isEmpty && _attachedFile == null) return;

    setState(() {
      _messages.add({'role': 'user', 'content': userText});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    String response;
    if (_attachedFile != null) {
      String base64Image;
      try {
        if (_attachedFile!.bytes != null) {
          base64Image = base64Encode(_attachedFile!.bytes!);
        } else if (_attachedFile!.path != null) {
          final bytes = await File(_attachedFile!.path!).readAsBytes();
          base64Image = base64Encode(bytes);
        } else {
          throw Exception("Dosya okunamadı.");
        }
        response = await _openAIService.chatGPTWithImage(userText, base64Image);
        setState(() { _attachedFile = null; });
      } catch (e) {
        response = "Resim işlenirken hata oluştu: $e";
      }
    } else {
      response = await _openAIService.chatGPTAPI(userText);
    }

    setState(() {
      _messages.add({'role': 'assistant', 'content': response});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _searchWeb() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': 'Web araması: $query'});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    String response = await _openAIService.webSearchAPI(query);
    setState(() {
      _messages.add({'role': 'assistant', 'content': response});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      final file = result.files.first;
      final ext = file.extension?.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        setState(() {
          _attachedFile = file;
          _messages.add({'role': 'system', 'content': 'Resim eklendi: ${file.name}'});
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Desteklenmeyen dosya türü: ${file.name}'});
        });
        _scrollToBottom();
      }
    }
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Speda', style: TextStyle(
                fontFamily: 'Logirent', fontFamilyFallback: ['Roboto'],
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 50,
              )),
              SizedBox(height: 20),
              Text('Size nasıl yardımcı olabilirim?', style: TextStyle(
                fontFamily: 'Azbuka', fontFamilyFallback: ['Roboto'],
                color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18,
              )),
            ],
          ),
        ),
      );
    } else {
      return ListView.builder(
        controller: _scrollController,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final isUser = _messages[index]['role'] == 'user';
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.50,
                minWidth: 100,
              ),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blueGrey.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUser ? Colors.lightBlue : Colors.blueAccent, width: 1,
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3),
                )],
              ),
              child: MarkdownBody(
                data: _messages[index]['content'] ?? '',
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white),
                  strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue.shade300),
                  code: TextStyle(
                    backgroundColor: Colors.lightBlue.withOpacity(0.05),
                    color: Colors.lightBlue.shade100, fontFamily: 'RobotoMono',
                  ),
                  h1: TextStyle(fontSize: 22, color: Colors.lightBlue.shade300, fontWeight: FontWeight.bold),
                  h2: TextStyle(fontSize: 20, color: Colors.lightBlue.shade300, fontWeight: FontWeight.bold),
                  a: const TextStyle(color: Colors.blueAccent),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0D10), Color(0xFF1B2027)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: const Border(bottom: BorderSide(color: Colors.blueGrey, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.rectangle),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('speda', style: TextStyle(
                            fontFamily: 'Logirent', fontFamilyFallback: ['Roboto'],
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22,
                          )),
                          Text('gpt-4o-mini', style: TextStyle(
                            fontFamily: 'Azbuka', fontFamilyFallback: ['Roboto'],
                            color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14,
                          )),
                        ],
                      ),
                      const Spacer(),
                      _currentUser == null
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                              onPressed: _signIn,
                              child: const Text("Google ile Giriş Yap", style: TextStyle(color: Colors.white)),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("Hoş Geldin, ${_currentUser!.displayName}",
                                  style: const TextStyle(color: Colors.white)),
                            ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMessageList(),
                      if (_isLoading)
                        Positioned(
                          bottom: 16, left: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent, width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SpinKitThreeBounce(color: Colors.lightBlue, size: 20.0),
                                SizedBox(width: 12),
                                Text('Yazıyor...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: const Border(top: BorderSide(color: Colors.blueGrey, width: 1)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Mesaj gönder ya da arama yap...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true, fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _uploadFile,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.green,
                            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.attach_file, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.blueAccent,
                            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _searchWeb,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.lightBlue,
                            boxShadow: [BoxShadow(color: Colors.lightBlue.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
