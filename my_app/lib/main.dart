import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Manim Chatbot',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainScreen(),
    );
  }
}

// Modèle de message
class Message {
  final String text;
  final bool isUser;
  final String? videoUrl;
  final bool isError;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    this.videoUrl,
    this.isError = false,
    required this.timestamp,
  });
}

// Modèle de conversation
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Message> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

// Écran principal avec navigation
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;

  @override
  void initState() {
    super.initState();
    _createNewChat();
  }

  void _createNewChat() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Nouveau chat',
      createdAt: DateTime.now(),
      messages: [],
    );
    
    setState(() {
      _sessions.insert(0, newSession);
      _currentSession = newSession;
      _selectedIndex = 0;
    });
  }

  void _selectChat(ChatSession session) {
    setState(() {
      _currentSession = session;
      _selectedIndex = 0;
    });
  }

  void _deleteChat(ChatSession session) {
    setState(() {
      _sessions.remove(session);
      if (_currentSession?.id == session.id) {
        if (_sessions.isEmpty) {
          _createNewChat();
        } else {
          _currentSession = _sessions.first;
        }
      }
    });
  }

  void _updateSessionTitle(String firstMessage) {
    if (_currentSession != null && _currentSession!.title == 'Nouveau chat') {
      setState(() {
        final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
        if (index != -1) {
          _sessions[index] = ChatSession(
            id: _currentSession!.id,
            title: firstMessage.length > 30 
                ? '${firstMessage.substring(0, 30)}...' 
                : firstMessage,
            createdAt: _currentSession!.createdAt,
            messages: _currentSession!.messages,
          );
          _currentSession = _sessions[index];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Barre latérale (sidebar)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.grey[50],
            selectedIconTheme: const IconThemeData(
              color: Colors.deepPurple,
              size: 28,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey[600],
              size: 24,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.chat_outlined),
                selectedIcon: Icon(Icons.chat),
                label: Text('Chat'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Historique'),
              ),
            ],
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          // Contenu principal
          Expanded(
            child: _selectedIndex == 0
                ? ChatScreen(
                    session: _currentSession,
                    onMessageSent: (msg) {
                      if (_currentSession!.messages.isEmpty) {
                        _updateSessionTitle(msg);
                      }
                    },
                    onNewChat: _createNewChat,
                  )
                : HistoryScreen(
                    sessions: _sessions,
                    onSelectChat: _selectChat,
                    onDeleteChat: _deleteChat,
                  ),
          ),
        ],
      ),
    );
  }
}

// Écran de chat
class ChatScreen extends StatefulWidget {
  final ChatSession? session;
  final Function(String) onMessageSent;
  final VoidCallback onNewChat;

  const ChatScreen({
    Key? key,
    required this.session,
    required this.onMessageSent,
    required this.onNewChat,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  final String apiBase = 'https://co4869.pythonanywhere.com';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.session == null) return;

    widget.onMessageSent(text);

    setState(() {
      widget.session!.messages.add(Message(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _loading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/generate/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': text}),
      ).timeout(const Duration(seconds: 300));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['video_url'] != null) {
          setState(() {
            widget.session!.messages.add(Message(
              text: 'Vidéo générée avec succès ! 🎬',
              isUser: false,
              videoUrl: '$apiBase${data['video_url']}',
              timestamp: DateTime.now(),
            ));
          });
        } else {
          setState(() {
            widget.session!.messages.add(Message(
              text: data['error'] ?? 'Erreur inconnue',
              isUser: false,
              isError: true,
              timestamp: DateTime.now(),
            ));
          });
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        widget.session!.messages.add(Message(
          text: 'Erreur de connexion: ${e.toString()}',
          isUser: false,
          isError: true,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session!.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: widget.onNewChat,
            tooltip: 'Nouveau chat',
            iconSize: 28,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.session!.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.session!.messages.length,
                    itemBuilder: (context, index) {
                      return _MessageBubble(
                        message: widget.session!.messages[index],
                      );
                    },
                  ),
          ),
          if (_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.05),
                border: Border(
                  top: BorderSide(color: Colors.deepPurple.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Génération de la vidéo en cours...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.video_library_rounded,
              size: 80,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Manim Chatbot',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Créez des vidéos éducatives animées avec l\'IA',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Décrivez la vidéo à créer...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _loading
                      ? [Colors.grey[400]!, Colors.grey[400]!]
                      : [Colors.deepPurple, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: _loading
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _sendMessage,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget de bulle de message
class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: message.isUser
              ? LinearGradient(
                  colors: [Colors.deepPurple, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: message.isUser
              ? null
              : message.isError
                  ? Colors.red[50]
                  : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: message.isError
              ? Border.all(color: Colors.red[200]!, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isError)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Erreur',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : message.isError
                          ? Colors.red[900]
                          : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            if (message.videoUrl != null) ...[
              const SizedBox(height: 12),
              _VideoPlayer(url: message.videoUrl!),
            ],
            const SizedBox(height: 6),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: message.isUser
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Widget de lecteur vidéo amélioré
class _VideoPlayer extends StatefulWidget {
  final String url;

  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.network(widget.url);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
    
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });

    // Masquer les contrôles après 3 secondes si la vidéo joue
    if (_controller!.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'Chargement de la vidéo...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: GestureDetector(
            onTap: () {
              setState(() => _showControls = !_showControls);
              if (_showControls && _controller!.value.isPlaying) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _controller!.value.isPlaying) {
                    setState(() => _showControls = false);
                  }
                });
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vidéo
                VideoPlayer(_controller!),
                
                // Overlay gradient
                if (_showControls || !_controller!.value.isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                
                // Bouton play/pause central
                if (_showControls || !_controller!.value.isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 48,
                      icon: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                
                // Contrôles en bas
                if (_showControls || !_controller!.value.isPlaying)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          // Barre de progression
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: EdgeInsets.zero,
                            colors: VideoProgressColors(
                              playedColor: Colors.deepPurple,
                              bufferedColor: Colors.white.withOpacity(0.3),
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Infos et contrôles
                          Row(
                            children: [
                              // Temps
                              Text(
                                '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // Bouton plein écran/téléchargement
                              IconButton(
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  // Ouvrir dans le navigateur
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Ouvrir la vidéo'),
                                      content: Text('URL: ${widget.url}'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Fermer'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Écran d'historique
class HistoryScreen extends StatelessWidget {
  final List<ChatSession> sessions;
  final Function(ChatSession) onSelectChat;
  final Function(ChatSession) onDeleteChat;

  const HistoryScreen({
    Key? key,
    required this.sessions,
    required this.onSelectChat,
    required this.onDeleteChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historique des conversations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Aucune conversation',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commencez un nouveau chat pour démarrer',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: InkWell(
                    onTap: () => onSelectChat(session),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.withOpacity(0.1),
                                  Colors.purple.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.deepPurple,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${session.messages.length} messages • ${_formatDate(session.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.grey[400],
                            ),
                            onPressed: () => _confirmDelete(context, session),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: const Text('Voulez-vous vraiment supprimer cette conversation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              onDeleteChat(session);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
