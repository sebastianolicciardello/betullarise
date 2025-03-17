import 'package:flutter/material.dart';
import 'features/tasks/tasks_page.dart';
import 'features/habits/habits_page.dart';
import 'features/rewards/rewards_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.black,
          secondary: Colors.black,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          bodySmall: TextStyle(color: Colors.black),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int rewardsCount = 5;

  final List<Widget> _pages = const [TasksPage(), HabitsPage(), RewardsPage()];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                // Azione da eseguire quando si tocca l'icona della gift card
                print('Icona della gift card toccata');
              },
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, size: 30, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    '$rewardsCount',
                    style: TextStyle(fontSize: 24, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.loop_rounded),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_rounded),
            label: 'Rewards',
          ),
        ],
      ),
    );
  }
}
