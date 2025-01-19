import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  List<Folder> folders = [];
  String? currentSong;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    loadLastPlayedSong();
    loadFolders();
    
    audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() => duration = d);
    });
    
    audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() => position = p);
    });
  }

  Future<void> loadLastPlayedSong() async {
    final prefs = await SharedPreferences.getInstance();
    currentSong = prefs.getString('lastPlayed');
    if (currentSong != null) {
      await audioPlayer.setSource(DeviceFileSource(currentSong!));
    }
  }

  Future<void> loadFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory(directory.path);
    final List<FileSystemEntity> entities = await dir.list().toList();
    
    setState(() {
      folders = entities
          .whereType<Directory>()
          .map((e) => Folder(name: e.path.split('/').last, path: e.path))
          .toList();
    });
  }

  Future<void> createFolder(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final newFolder = await Directory('${directory.path}/$name').create();
    
    setState(() {
      folders.add(Folder(name: name, path: newFolder.path));
    });
  }

  Future<void> uploadSongs(String folderPath) async {
    // Here you would implement file picking logic
    // For demonstration, we'll just show the UI
  }

  Future<void> playSong(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPlayed', path);
    
    setState(() {
      currentSong = path;
      isPlaying = true;
    });
    
    await audioPlayer.play(DeviceFileSource(path));
  }

  void shufflePlay(String folderPath) async {
    final folder = Directory(folderPath);
    final files = await folder
        .list()
        .where((entity) => entity.path.endsWith('.mp3'))
        .toList();
    
    if (files.isEmpty) return;
    
    final randomFile = files[Random().nextInt(files.length)];
    await playSong(randomFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music Player'),
        backgroundColor: Colors.green[900],
      ),
      body: Column(
        children: [
          // Now Playing Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  'Now Playing',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentSong?.split('/').last ?? 'No song selected',
                  style: const TextStyle(color: Colors.white70),
                ),
                Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  activeColor: Colors.green[400],
                  onChanged: (value) async {
                    await audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          audioPlayer.pause();
                        } else {
                          audioPlayer.resume();
                        }
                        setState(() => isPlaying = !isPlaying);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Folders List
          Expanded(
            child: ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.folder, color: Colors.green),
                  title: Text(folders[index].name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        onPressed: () => uploadSongs(folders[index].path),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shuffle, color: Colors.white),
                        onPressed: () => shufflePlay(folders[index].path),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.create_new_folder),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              String newFolderName = '';
              return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text('Create New Folder', style: TextStyle(color: Colors.white)),
                content: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Folder Name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  onChanged: (value) => newFolderName = value,
                ),
                actions: [
                  TextButton(
                    child: const Text('Create', style: TextStyle(color: Colors.green)),
                    onPressed: () {
                      if (newFolderName.isNotEmpty) {
                        createFolder(newFolderName);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class Folder {
  final String name;
  final String path;
  
  Folder({required this.name, required this.path});
}