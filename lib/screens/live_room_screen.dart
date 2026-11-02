import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// In the class: everyone's video, plus mic and camera switches the server allowed for this person.
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key, required this.join});

  /// The join response: serverUrl, token, canMic, canCamera and the class details.
  final Map<String, dynamic> join;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final Room _room = Room();
  late final EventsListener<RoomEvent> _events = _room.createListener();
  String? _error;
  bool _connecting = true;

  bool get _canMic => widget.join['canMic'] == true;
  bool get _canCamera => widget.join['canCamera'] == true;

  @override
  void initState() {
    super.initState();
    _events.listen((_) {
      if (mounted) setState(() {});
    });
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _room.connect(widget.join['serverUrl'] as String, widget.join['token'] as String);
      if (!mounted) return;
      setState(() => _connecting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Could not connect to the class. Check the connection and try again.';
        });
      }
    }
  }

  Future<void> _toggleMic() async {
    final local = _room.localParticipant;
    if (local == null) return;
    await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    final local = _room.localParticipant;
    if (local == null) return;
    await local.setCameraEnabled(!local.isCameraEnabled());
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    await _room.disconnect();
    navigator.pop();
  }

  @override
  void dispose() {
    _events.dispose();
    _room.disconnect();
    _room.dispose();
    super.dispose();
  }

  /// A screen share comes first: it is what the trainer wants everyone to look at.
  VideoTrack? _videoOf(Participant p) {
    VideoTrack? camera;
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (track is! VideoTrack || pub.muted) continue;
      if (pub.isScreenShare) return track;
      camera ??= track;
    }
    return camera;
  }

  @override
  Widget build(BuildContext context) {
    final local = _room.localParticipant;
    final people = <Participant>[
      ..._room.remoteParticipants.values,
      if (local != null) local,
    ];
    final title = widget.join['topic'] as String? ?? widget.join['courseTitle'] as String? ?? 'Live class';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : GridView.count(
                  crossAxisCount: people.length <= 1 ? 1 : 2,
                  padding: const EdgeInsets.all(8),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: people.length <= 1 ? 16 / 10 : 4 / 3,
                  children: [for (final p in people) _Tile(participant: p, video: _videoOf(p), isMe: identical(p, local))],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton.filledTonal(
              onPressed: _canMic && !_connecting ? _toggleMic : null,
              icon: Icon(local?.isMicrophoneEnabled() == true ? Icons.mic : Icons.mic_off),
              tooltip: _canMic ? 'Microphone' : 'Microphone is off for students',
            ),
            IconButton.filledTonal(
              onPressed: _canCamera && !_connecting ? _toggleCamera : null,
              icon: Icon(local?.isCameraEnabled() == true ? Icons.videocam : Icons.videocam_off),
              tooltip: _canCamera ? 'Camera' : 'Camera is off for students',
            ),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _leave,
              icon: const Icon(Icons.call_end),
              tooltip: 'Leave',
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.participant, required this.video, required this.isMe});

  final Participant participant;
  final VideoTrack? video;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = participant.name.isNotEmpty ? participant.name : participant.identity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          border: participant.isSpeaking ? Border.all(color: Colors.greenAccent, width: 3) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (video != null)
            VideoTrackRenderer(video!)
          else
            const Center(child: Icon(Icons.person, size: 48, color: Colors.white54)),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: Text(isMe ? '$name (you)' : name, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ]),
      ),
    );
  }
}
