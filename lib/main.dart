

// Main code (lib/main.dart):
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

void main()  async {
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
  Map<String, List<String>> folderSongs = {};
  String? currentSong;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await loadLastPlayedSong();
    await loadFolders();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      final manageStorage = await Permission.manageExternalStorage.request();
      
      if (storage.isDenied || manageStorage.isDenied) {
        // Show dialog explaining why permissions are needed
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Permissions Required', 
                style: TextStyle(color: Colors.white)),
              content: const Text(
                'Storage permissions are required to manage music files.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  child: const Text('Open Settings', 
                    style: TextStyle(color: Colors.green)),
                  onPressed: () => openAppSettings(),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> loadLastPlayedSong() async {
    final prefs = await SharedPreferences.getInstance();
    currentSong = prefs.getString('lastPlayed');
    if (currentSong != null) {
      await audioPlayer.setSource(DeviceFileSource(currentSong!));
    }
  }

  Future<void> loadFolders() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      
      // Load folders
      final loadedFolders = entities
          .whereType<Directory>()
          .map((e) => Folder(name: e.path.split('/').last, path: e.path))
          .toList();

      // Load songs for each folder
      for (var folder in loadedFolders) {
        final folderDir = Directory(folder.path);
        if (await folderDir.exists()) {
          final songs = await folderDir
              .list()
              .where((entity) => 
                entity.path.endsWith('.mp3') || 
                entity.path.endsWith('.m4a') || 
                entity.path.endsWith('.wav'))
              .map((entity) => entity.path)
              .toList();
          folderSongs[folder.path] = songs;
        }
      }

      setState(() {
        folders = loadedFolders;
      });
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }
  }

  Future<void> createFolder(String name) async {
  try {
    // Add print statement for debugging
    print("Starting folder creation...");
    
    final directory = await getApplicationDocumentsDirectory();
    print("Got directory: ${directory.path}");
    
    final newFolder = await Directory('${directory.path}/$name').create(recursive: true);
    print("Created folder at: ${newFolder.path}");
    
    setState(() {
      folders.add(Folder(name: name, path: newFolder.path));
      folderSongs[newFolder.path] = [];
    });
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder "$name" created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print("Error creating folder: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}  Future<void> uploadSongs(String folderPath) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            final newFile = await File(file.path!)
                .copy('$folderPath/${file.name}');
            
            setState(() {
              if (!folderSongs.containsKey(folderPath)) {
                folderSongs[folderPath] = [];
              }
              folderSongs[folderPath]!.add(newFile.path);
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Uploaded: ${file.name}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> playSong(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastPlayed', path);
      
      setState(() {
        currentSong = path;
        isPlaying = true;
      });
      
      await audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void shufflePlay(String folderPath) async {
    if (folderSongs[folderPath]?.isEmpty ?? true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No songs in this folder'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final songs = folderSongs[folderPath]!;
    final randomSong = songs[Random().nextInt(songs.length)];
    await playSong(randomSong);
  }

  void showFolderContents(String folderPath, String folderName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    folderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file, color: Colors.green),
                    onPressed: () async {
                      Navigator.pop(context);
                      await uploadSongs(folderPath);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: folderSongs[folderPath]?.isEmpty ?? true
                    ? const Center(
                        child: Text(
                          'No songs in this folder',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: folderSongs[folderPath]?.length ?? 0,
                        itemBuilder: (context, index) {
                          final song = folderSongs[folderPath]![index];
                          final songName = song.split('/').last;
                          return ListTile(
                            leading: const Icon(Icons.music_note, color: Colors.green),
                            title: Text(
                              songName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              playSong(song);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
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
            child: folders.isEmpty
                ? const Center(
                    child: Text(
                      'No folders yet\nClick + to create a folder',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.green),
                        title: Text(folders[index].name),
                        subtitle: Text(
                          '${folderSongs[folders[index].path]?.length ?? 0} songs',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () => showFolderContents(
                          folders[index].path,
                          folders[index].name,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.upload_file, color: Colors.white),
                              onPressed: () => uploadSongs(folders[index].path),
                              tooltip: 'Upload Songs',
                            ),
                            IconButton(
                              icon: const Icon(Icons.shuffle, color: Colors.white),
                              onPressed: () => shufflePlay(folders[index].path),
                              tooltip: 'Shuffle Play',
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
                title: const Text('Create New Folder', 
                  style: TextStyle(color: Colors.white)),
                content: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Folder Name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  onChanged: (value) => newFolderName = value,
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel', 
                      style: TextStyle(color: Colors.white70)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: const Text('Create', 
                      style: TextStyle(color: Colors.green)),
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

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}

class Folder {
  final String name;
  final String path;
  
  Folder({required this.name, required this.path});
}