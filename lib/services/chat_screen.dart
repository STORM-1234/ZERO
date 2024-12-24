import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback onClose;

  final double temperature;
  final double humidity;
  final double airQuality;
  final Map<String, double> gasLevels;

  const ChatScreen({
    Key? key,
    required this.onClose,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
    required this.gasLevels,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  Future<String> _generateResponse(String userInput) async {
    final model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-1.5-flash',
    );

    // Convert gas levels map to a readable string
    String gasData = widget.gasLevels.entries
        .map((e) => "${e.key}: ${e.value.toStringAsFixed(2)} ppm")
        .join(", ");

    // system prompt
    final prompt = [
      Content.text("""
    [System]
    You are ZERO AI, a friendly and concise assistant for the ZERO air quality monitoring app.
    The app displays real-time readings (temperature in °C, humidity, air quality on a 0-500 scale, and certain gas concentrations like CO2, NH3, benzene, sulfur).
    Air Quality Scale:
    0-50 good
    51-100 moderate
    101-150 slightly unhealthy
    151-200 unhealthy
    201-300 very unhealthy
    301-500 hazardous
    
    Current Real-Time Data:
    - Temperature: ${widget.temperature.toStringAsFixed(1)} °C
    - Humidity: ${widget.humidity.toStringAsFixed(1)}%
    - Air Quality Index: ${widget.airQuality.toStringAsFixed(0)}
    - Gas Levels: $gasData

    Your purpose:
    - Respond only to questions related to temperature, air quality, air pollution, weather, humidity, the ZERO app, or the ZERO module.
    - Always respond in a friendly tone, keep it short, and use emojis if possible.
    - Provide helpful, real-world suggestions when relevant.
    - If asked about connecting the ZERO module, provide the detailed steps below:
      1. Turn on your ZERO module and keep it near your phone.
      2. In the ZERO app, go to the "Connect Devices" tab.
      3. Tap the scan button. A camera view will open.
      4. Use the camera to scan the QR code on the back of your ZERO module.
      5. Once paired, choose the Wi-Fi network you want the module to connect to.
      6. Enter the target Wi-Fi SSID and password as prompted.
      7. After submission, if the Wi-Fi is available and both module and user device are online, the app will start showing real-time readings.
    - Avoid using the asterisk character (*).
    - If the user asks something outside these topics, politely inform them that you can only help with the listed topics.

    End of System Instructions.
    """),
      Content.text("User: $userInput")
    ];

    final response = await model.generateContent(prompt);
    return response.text ?? 'Sorry, I could not generate a response.';
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': message});
      _isLoading = true;
    });
    _textController.clear();

    try {
      final response = await _generateResponse(message);
      setState(() {
        _messages.add({'sender': 'bot', 'text': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Sorry, an error occurred.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['sender'] == 'user';
    final text = message['text'] ?? '';
    final currentUserPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Image.asset(
                'asset/logo/zero.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(isUser ? 15 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 15),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: currentUserPhotoUrl != null
                  ? NetworkImage(currentUserPhotoUrl)
                  : null,
              child: currentUserPhotoUrl == null
                  ? const Icon(Icons.person, color: Colors.black)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          _buildTopBar(context),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 10),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type your messages...',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_textController.text),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.send, color: Colors.black),
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
