import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:rackwebapp/models/rack.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> _ensureRackDataFileExists() async {
  final filePath = '/storage/emulated/0/rack_data.json';
  final file = File(filePath);
  if (!await file.exists()) {
    try {
      final String assetContent = await rootBundle.loadString('assets/rack_data.json');
      await file.create(recursive: true);
      await file.writeAsString(assetContent);
      print('Successfully copied asset file to external storage');
    } catch (e) {
      print('Error copying asset file: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureRackDataFileExists();
  // await requestPermissions(); // Removed as it's handled in HomePage initState
  runApp(MyApp());
}



class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rackulator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver { // Add WidgetsBindingObserver
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register observer
    _checkPermissions(requestIfNeeded: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissions(); // Removed context argument
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions when app comes back to foreground
      _checkPermissions(requestIfNeeded: false);
    }
  }

  Future<void> _checkPermissions({bool requestIfNeeded = true}) async {
    print('Checking permissions...');
    bool granted = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) { // Android 11+
        final manageExternalStatus = await Permission.manageExternalStorage.status;
        print('Current manage external status: $manageExternalStatus');
        granted = manageExternalStatus.isGranted;
      } else { // Older Android versions
        final storageStatus = await Permission.storage.status;
        print('Current storage status: $storageStatus');
        granted = storageStatus.isGranted;
      }
    } else { // Non-Android platforms (handle storage permission)
      final storageStatus = await Permission.storage.status;
      print('Current storage status: $storageStatus');
      granted = storageStatus.isGranted;
    }

    print('Permissions granted check result: $granted');

    if (mounted) { // Check if widget is still mounted
      setState(() {
        _permissionsGranted = granted;
      });
    }

    // Only request if not granted and requestIfNeeded is true
    if (!granted && requestIfNeeded) {
      print('Permissions not granted, requesting...');
      await requestPermissions();
    }
  }

  Future<void> requestPermissions() async {
    print('Requesting permissions...');
    bool permissionsNowGranted = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 30) { // Android 11+
        var manageStatus = await Permission.manageExternalStorage.status;
        print('Initial Manage external storage status: $manageStatus');

        if (!manageStatus.isGranted) {
          manageStatus = await Permission.manageExternalStorage.request();
          print('Manage external storage status after request: $manageStatus');

          if (manageStatus.isPermanentlyDenied) {
            print('Manage external storage permanently denied, opening app settings.');
            await openAppSettings();
            // No immediate return, let the lifecycle observer handle re-check
          }
        }
        // Re-check status after request or if it was already granted
        final currentManageStatus = await Permission.manageExternalStorage.status;
        permissionsNowGranted = currentManageStatus.isGranted;

      } else { // Android 6 to 10 (API 23-29)
        var storageStatus = await Permission.storage.status;
        print('Initial Storage permission status: $storageStatus');

        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
          print('Storage permission status after request: $storageStatus');

          if (storageStatus.isPermanentlyDenied) {
            print('Storage permission permanently denied, opening app settings.');
            await openAppSettings();
             // No immediate return, let the lifecycle observer handle re-check
          }
        }
         // Re-check status after request or if it was already granted
        final currentStorageStatus = await Permission.storage.status;
        permissionsNowGranted = currentStorageStatus.isGranted;
      }
    } else { // Non-Android platforms
      var status = await Permission.storage.status;
       print('Initial Storage permission status (non-Android): $status');
       if(!status.isGranted) {
          status = await Permission.storage.request();
          print('Storage permission status after request (non-Android): $status');
          if (status.isPermanentlyDenied) {
             print('Storage permission permanently denied, opening app settings.');
             await openAppSettings();
              // No immediate return, let the lifecycle observer handle re-check
          }
       }
       final currentStatus = await Permission.storage.status;
       permissionsNowGranted = currentStatus.isGranted;
    }

    print('Permissions granted after request logic: $permissionsNowGranted');
    if (mounted) {
      setState(() => _permissionsGranted = permissionsNowGranted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rackulator'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Display a warning message if permissions are not granted
            if (!_permissionsGranted)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Storage permissions are required for this app to function properly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RackView()),
                );
              },
              child: Text('Go to Rack View'),
            ),
            ElevatedButton(
              onPressed: () async {
                final passwordController = TextEditingController();
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Admin Login'),
                    content: TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(hintText: 'Enter password'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (passwordController.text == '2521') {
                            Navigator.pop(context, true);
                          } else {
                            if (context != null) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Incorrect password')),
                            );
                          }
                        },
                        child: Text('Login'),
                      ),
                    ],
                  ),
                );
                if (result == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdminPanel()),
                  );
                }
              },
              child: Text('Go to Admin Panel'),
            ),
          ],
        ),
      ),
    );
  }
}

class RackView extends StatelessWidget {
  final Future<RackData> rackData = loadRackData();

  static Future<RackData> loadRackData() async {
    final String filePath = '/storage/emulated/0/rack_data.json';
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        // If file does not exist, create an empty structure
        await file.create(recursive: true);
        await file.writeAsString('{"categories": []}');
      }
      final String response = await file.readAsString();
      if (response.isEmpty) {
        return RackData.fromJson({"categories": []});
      }
      final data = json.decode(response);
      if (data == null || data is! Map) {
        return RackData.fromJson({"categories": []});
      }
      return RackData.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      print('Error loading rack data: $e');
      return RackData.fromJson({"categories": []});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rack View'),
      ),
      body: FutureBuilder<RackData>(
        future: rackData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading data'));
          } else {
            final rackData = snapshot.data!; // Add null check
            return ListView.builder(
              itemCount: rackData?.categories.length ?? 0,
              itemBuilder: (context, index) {
                final category = rackData.categories[index];
                return ExpansionTile(
                  title: Text(category.name),
                  children: category.models.map((model) {
                    final totalAreaMm2 = model.lengthMm * model.widthMm;
                    final totalAreaM2 = totalAreaMm2 / 1000000;
                    final totalArea = totalAreaM2 * model.quantityFor1Rack * 2;
                    final totalPaintKg = totalArea / 7;
                    final totalPaintG = totalPaintKg * 1000;
                    return ListTile(
                      title: Text(model.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.description),
                          Text('Total Paint: ${totalPaintKg.toStringAsFixed(2)} kg (${totalPaintG.toStringAsFixed(2)} g)')
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  final String filePath = '/storage/emulated/0/rack_data.json';
  
  Future<String> _loadFile() async {
    try {
      // First check if the file exists in external storage
      final file = File(filePath); // Ensure the file path is correct and accessible
      if (!await file.exists()) {
        // If not, copy from assets
        try {
          // Create the file with directory structure if needed
          await file.create(recursive: true);
          
          // Load from assets bundle
          final String assetContent = await rootBundle.loadString('assets/rack_data.json');
          
          // Write to external storage
          await file.writeAsString(assetContent);
          print('Successfully copied asset file to external storage');
          return assetContent;
        } catch (assetError) {
          print('Error copying from assets: $assetError');
          // If asset loading fails, create an empty structure
          await file.writeAsString('{"categories": []}');
          return '{"categories": []}';
        }
      }
      
      // Read from external storage
      final content = await file.readAsString();
      if (content.isEmpty) {
        return '{"categories": []}';
      }
      return content;
    } catch (e) {
      print('Error loading file: $e');
      return '{"categories": []}';
    }
  }
  
  Future<void> _saveFile(String content, BuildContext context) async {
    try {
      final file = File(filePath);
      // Ensure directory exists
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      // Write the content (json.encode handles empty lists correctly)
      await file.writeAsString(content);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved successfully')),
      );
    } catch (e) {
      print('Error saving file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                final data = await _loadFile();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditCategories(initialData: data)),
                );
                if (result != null) {
                  await _saveFile(result, context);
                }
              },
              child: Text('Edit Categories'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = await _loadFile();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditData(initialData: data)),
                );
                if (result != null) {
                  await _saveFile(result, context);
                }
              },
              child: Text('Edit Data'),
            ),

          ],
        ),
      ),
    );
  }
}

class EditCategories extends StatefulWidget {
  final String initialData;
  EditCategories({required this.initialData});
  @override
  _EditCategoriesState createState() => _EditCategoriesState();
}

class _EditCategoriesState extends State<EditCategories> {
  late List categories;
  int? selectedCategoryIndex;
  final categoryNameController = TextEditingController();
  final subCategoryNameController = TextEditingController();
  int? selectedSubCategoryIndex;

  @override
  void initState() {
    super.initState();
    final data = json.decode(widget.initialData);
    categories = data['categories'] ?? [];
    if (categories.isNotEmpty) selectedCategoryIndex = 0;
  }

  void addCategory() {
    final newName = categoryNameController.text.trim();
    if (newName.isEmpty) return;
    
    setState(() {
      // Check if category with same name exists
      final existingIndex = categories.indexWhere((cat) => cat['name'] == newName);
      
      if (existingIndex >= 0) {
        // Category exists, select it
        selectedCategoryIndex = existingIndex;
        selectedSubCategoryIndex = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category already exists, selected it instead')),
        );
      } else {
        // Add new category
        categories.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': newName,
          'models': []
        });
        selectedCategoryIndex = categories.length - 1;
        selectedSubCategoryIndex = null;
      }
      
      categoryNameController.clear();
    });
  }

  void removeCategory() {
    if (selectedCategoryIndex != null && categories.isNotEmpty) {
      setState(() {
        categories.removeAt(selectedCategoryIndex!);
        if (categories.isNotEmpty) {
          selectedCategoryIndex = 0;
        } else {
          selectedCategoryIndex = null;
        }
        selectedSubCategoryIndex = null;
      });
    }
  }

  void editCategoryName() {
    if (selectedCategoryIndex != null) {
      setState(() {
        categories[selectedCategoryIndex!]['name'] = categoryNameController.text;
        categoryNameController.clear();
      });
    }
  }

  void addSubCategory() {
    if (selectedCategoryIndex != null) {
      setState(() {
        categories[selectedCategoryIndex!]['models'].add({
          'name': subCategoryNameController.text,
          'description': '',
          'lengthMm': 0,
          'widthMm': 0,
          'quantityFor1Rack': 0
        });
        subCategoryNameController.clear();
        selectedSubCategoryIndex = categories[selectedCategoryIndex!]['models'].length - 1;
      });
    }
  }

  void removeSubCategory() {
    if (selectedCategoryIndex != null && selectedSubCategoryIndex != null) {
      setState(() {
        categories[selectedCategoryIndex!]['models'].removeAt(selectedSubCategoryIndex!);
        selectedSubCategoryIndex = null;
      });
    }
  }

  void editSubCategoryName() {
    if (selectedCategoryIndex != null && selectedSubCategoryIndex != null) {
      setState(() {
        categories[selectedCategoryIndex!]['models'][selectedSubCategoryIndex!]['name'] = subCategoryNameController.text;
        subCategoryNameController.clear();
      });
    }
  }

  void save() {
    final data = {'categories': categories};
    Navigator.pop(context, json.encode(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Categories')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories:'),
            DropdownButton<int>(
              value: selectedCategoryIndex,
              hint: Text('Select Category'),
              items: List.generate(categories.length, (i) => DropdownMenuItem(
                value: i,
                child: Text(categories[i]['name'] ?? ''),
              )),
              onChanged: (i) {
                setState(() {
                  selectedCategoryIndex = i;
                  selectedSubCategoryIndex = null;
                });
              },
            ),
            Column(
              children: [
                Text('Create New Main Category:'),
                TextField(
                  controller: categoryNameController,
                  decoration: InputDecoration(labelText: 'New Category Name'),
                ),
                ElevatedButton(
                  onPressed: addCategory,
                  child: Text('Create New Main Category'),
                ),
                SizedBox(height: 16),
                Text('Add Subcategory to Existing Category:'),
                DropdownButton<int>(
                  value: selectedCategoryIndex,
                  hint: Text('Select Main Category'),
                  items: List.generate(categories.length, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(categories[i]['name'] ?? ''),
                  )),
                  onChanged: (i) {
                    setState(() {
                      selectedCategoryIndex = i;
                    });
                  },
                ),
                TextField(
                  controller: subCategoryNameController,
                  decoration: InputDecoration(labelText: 'Subcategory Name'),
                ),
                ElevatedButton(
                  onPressed: addSubCategory,
                  child: Text('Add Subcategory'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Delete Categories:'),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Main Category:'),
                      DropdownButton<int>(
                        value: selectedCategoryIndex,
                        hint: Text('Select Main Category'),
                        items: List.generate(categories.length, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(categories[i]['name'] ?? ''),
                        )),
                        onChanged: (i) {
                          setState(() {
                            selectedCategoryIndex = i;
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: removeCategory,
                        child: Text('Delete Main Category'),
                      ),
                    ],
                  ),
                ),
                if (selectedCategoryIndex != null)
                  Expanded(
                    child: Column(
                      children: [
                        Text('Subcategory:'),
                        DropdownButton<int>(
                          value: selectedSubCategoryIndex,
                          hint: Text('Select Subcategory'),
                          items: List.generate(categories[selectedCategoryIndex!]['models'].length, (i) => DropdownMenuItem(
                            value: i,
                            child: Text(categories[selectedCategoryIndex!]['models'][i]['name'] ?? ''),
                          )),
                          onChanged: (i) {
                            setState(() {
                              selectedSubCategoryIndex = i;
                            });
                          },
                        ),
                        ElevatedButton(
                          onPressed: removeSubCategory,
                          child: Text('Delete Subcategory'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Spacer(),
            ElevatedButton(onPressed: save, child: Text('Save Changes')),
          ],
        ),
      ),
    );
  }
}

class EditData extends StatefulWidget {
  final String initialData;
  EditData({required this.initialData});
  @override
  _EditDataState createState() => _EditDataState();
}

class _EditDataState extends State<EditData> {
  late List categories;
  int? selectedCategoryIndex;
  int? selectedModelIndex;
  final valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = json.decode(widget.initialData);
    categories = data['categories'] ?? [];
    if (categories.isNotEmpty) selectedCategoryIndex = 0;
    if (selectedCategoryIndex != null && categories[selectedCategoryIndex!]['models'].isNotEmpty) {
      selectedModelIndex = 0;
      valueController.text = categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['description'] ?? '';
    }
  }

  void save() {
    if (selectedCategoryIndex != null && selectedModelIndex != null) {
      categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['description'] = valueController.text;
      final data = {'categories': categories};
      Navigator.pop(context, json.encode(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Category:'),
            DropdownButton<int>(
              value: selectedCategoryIndex,
              hint: Text('Select Category'),
              items: List.generate(categories.length, (i) => DropdownMenuItem(
                value: i,
                child: Text(categories[i]['name'] ?? ''),
              )),
              onChanged: (i) {
                setState(() {
                  selectedCategoryIndex = i;
                  selectedModelIndex = null;
                  if (i != null && categories[i]['models'].isNotEmpty) {
                    selectedModelIndex = 0;
                    valueController.text = categories[i]['models'][0]['description'] ?? '';
                  } else {
                    valueController.clear();
                  }
                });
              },
            ),
            if (selectedCategoryIndex != null) ...[
              Text('Subcategory:'),
              DropdownButton<int>(
                value: selectedModelIndex,
                hint: Text('Select Subcategory'),
                items: List.generate(categories[selectedCategoryIndex!]['models'].length, (i) => DropdownMenuItem(
                  value: i,
                  child: Text(categories[selectedCategoryIndex!]['models'][i]['name'] ?? ''),
                )),
                onChanged: (i) {
                  setState(() {
                    selectedModelIndex = i;
                    if (i != null) {
                      valueController.text = categories[selectedCategoryIndex!]['models'][i]['description'] ?? '';
                      setState(() {}); // Force rebuild to update all fields
                    } else {
                      valueController.clear();
                    }
                  });
                },
              ),
            ],
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'Description',
              ),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Length (mm)',
              ),
              onChanged: (value) {
                if (selectedCategoryIndex != null && selectedModelIndex != null) {
                  categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['lengthMm'] = double.tryParse(value) ?? 0.0;
                }
              },
              controller: TextEditingController(
                text: selectedCategoryIndex != null && selectedModelIndex != null 
                  ? categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['lengthMm']?.toString() ?? '' 
                  : ''
              ),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Width (mm)',
              ),
              onChanged: (value) {
                if (selectedCategoryIndex != null && selectedModelIndex != null) {
                  categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['widthMm'] = double.tryParse(value) ?? 0.0;
                }
              },
              controller: TextEditingController(
                text: selectedCategoryIndex != null && selectedModelIndex != null 
                  ? categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['widthMm']?.toString() ?? '' 
                  : ''
              ),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity per Rack',
              ),
              onChanged: (value) {
                if (selectedCategoryIndex != null && selectedModelIndex != null) {
                  categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['quantityFor1Rack'] = double.tryParse(value) ?? 0.0;
                }
              },
              controller: TextEditingController(
                text: selectedCategoryIndex != null && selectedModelIndex != null 
                  ? categories[selectedCategoryIndex!]['models'][selectedModelIndex!]['quantityFor1Rack']?.toString() ?? '' 
                  : ''
              ),
            ),
            ElevatedButton(
              onPressed: save,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddDeleteCategories extends StatefulWidget {
  final String initialData;
  AddDeleteCategories({required this.initialData});
  @override
  _AddDeleteCategoriesState createState() => _AddDeleteCategoriesState();
}

class _AddDeleteCategoriesState extends State<AddDeleteCategories> {
  late List categories;
  final categoryNameController = TextEditingController();
  final subCategoryNameController = TextEditingController();
  final subCategoryDescController = TextEditingController();
  final subCategoryLengthController = TextEditingController();
  final subCategoryWidthController = TextEditingController();
  final subCategoryQtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = json.decode(widget.initialData);
    categories = data['categories'] ?? [];
  }

  void addCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: categoryNameController,
                  decoration: InputDecoration(labelText: 'Category Name'),
                ),
                TextField(
                  controller: subCategoryNameController,
                  decoration: InputDecoration(labelText: 'Subcategory Name'),
                ),
                TextField(
                  controller: subCategoryDescController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: subCategoryLengthController,
                  decoration: InputDecoration(labelText: 'Length (mm)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: subCategoryWidthController,
                  decoration: InputDecoration(labelText: 'Width (mm)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: subCategoryQtyController,
                  decoration: InputDecoration(labelText: 'Quantity for 1 Rack'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  categories.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': categoryNameController.text,
                    'models': [
                      {
                        'name': subCategoryNameController.text,
                        'description': subCategoryDescController.text,
                        'lengthMm': int.tryParse(subCategoryLengthController.text) ?? 0,
                        'widthMm': int.tryParse(subCategoryWidthController.text) ?? 0,
                        'quantityFor1Rack': int.tryParse(subCategoryQtyController.text) ?? 0,
                      }
                    ]
                  });
                  categoryNameController.clear();
                  subCategoryNameController.clear();
                  subCategoryDescController.clear();
                  subCategoryLengthController.clear();
                  subCategoryWidthController.clear();
                  subCategoryQtyController.clear();
                });
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void deleteLastCategory() {
    setState(() {
      if (categories.isNotEmpty) {
        categories.removeLast();
      }
    });
  }

  void save() {
    final data = {'categories': categories};
    Navigator.pop(context, json.encode(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add/Delete Categories'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: addCategoryDialog,
              child: Text('Add Category'),
            ),
            ElevatedButton(
              onPressed: () {
                deleteLastCategory();
                if (context != null) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Last category deleted (if any)')),
                );
              },
              child: Text('Delete Last Category'),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: save,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
