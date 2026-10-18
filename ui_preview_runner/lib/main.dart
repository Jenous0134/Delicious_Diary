import 'package:flutter/material.dart';

void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '한끼일기 UI Preview',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF765237),
        surface: const Color(0xFFFFFCF7),
      ),
      scaffoldBackgroundColor: const Color(0xFFFFFCF7),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: Color(0xFFE8DED3)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    home: const Preview(),
  );
}

class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['오늘도 맛있는 하루', '캘린더', '식사 기록 추가', '검색 및 필터', '더보기'][index]),
    ),
    body: IndexedStack(
      index: index,
      children: const [Home(), Calendar(), Add(), Search(), More()],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => setState(() => index = 2),
      child: const Icon(Icons.add),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: '캘린더',
        ),
        NavigationDestination(icon: Icon(Icons.add), label: '기록'),
        NavigationDestination(icon: Icon(Icons.search), label: '검색'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
      ],
    ),
  );
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
    children: const [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Chip(label: Text('전체')),
            SizedBox(width: 8),
            Chip(label: Text('아침')),
            SizedBox(width: 8),
            Chip(label: Text('점심')),
            SizedBox(width: 8),
            Chip(label: Text('저녁')),
            SizedBox(width: 8),
            Chip(label: Text('간식')),
          ],
        ),
      ),
      SizedBox(height: 18),
      Text(
        '최근 식사',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      SizedBox(height: 12),
      MealCard('점심 · 을지로 맛집', '2026년 10월 18일', Icons.ramen_dining),
      SizedBox(height: 14),
      MealCard('저녁 · 집', '2026년 10월 17일', Icons.rice_bowl),
    ],
  );
}

class MealCard extends StatelessWidget {
  const MealCard(this.title, this.date, this.icon, {super.key});
  final String title, date;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.75,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ColoredBox(
                  color: const Color(0xFFE1C6A7),
                  child: Center(
                    child: Icon(icon, size: 76, color: const Color(0xFF765237)),
                  ),
                ),
              ),
              SizedBox(width: 3),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: Color(0xFFF0DCC7),
                        child: Center(
                          child: Icon(
                            Icons.local_cafe_outlined,
                            size: 40,
                            color: Color(0xFF765237),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 3),
                    Expanded(
                      child: ColoredBox(
                        color: Color(0xFFD7B18B),
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(date),
            ],
          ),
        ),
      ],
    ),
  );
}

class Calendar extends StatelessWidget {
  const Calendar({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.chevron_left),
            Text(
              '2026년 10월',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 7,
          children: List.generate(
            31,
            (i) => Center(
              child: CircleAvatar(
                backgroundColor: i == 17
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                child: Text('${i + 1}'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class Add extends StatelessWidget {
  const Add({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Padding(padding: EdgeInsets.all(30), child: Text('사진 추가')),
      ),
      const SizedBox(height: 20),
      const TextField(
        decoration: InputDecoration(labelText: '날짜 *', filled: true),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          '아침',
          '점심',
          '저녁',
          '간식',
          '야식',
          '기타',
        ].map((e) => ChoiceChip(label: Text(e), selected: e == '점심')).toList(),
      ),
      const SizedBox(height: 12),
      const TextField(
        decoration: InputDecoration(labelText: '장소 *', filled: true),
      ),
      const SizedBox(height: 12),
      const TextField(
        decoration: InputDecoration(labelText: '메뉴', filled: true),
      ),
    ],
  );
}

class Search extends StatelessWidget {
  const Search({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '메뉴, 장소, 메모 검색...',
          filled: true,
        ),
      ),
      SizedBox(height: 20),
      ListTile(title: Text('날짜'), trailing: Text('전체  ›')),
      ListTile(title: Text('장소'), trailing: Text('전체  ›')),
      ListTile(title: Text('메뉴'), trailing: Text('전체  ›')),
      ListTile(title: Text('같이 먹은 사람'), trailing: Text('전체  ›')),
    ],
  );
}

class More extends StatelessWidget {
  const More({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      ListTile(
        leading: Icon(Icons.backup_outlined),
        title: Text('백업 및 복원'),
        subtitle: Text('기록과 사진을 ZIP 파일로 내보내기/불러오기'),
      ),
      ListTile(leading: Icon(Icons.storage_outlined), title: Text('데이터 관리')),
      ListTile(leading: Icon(Icons.settings_outlined), title: Text('앱 설정')),
      ListTile(leading: Icon(Icons.info_outline), title: Text('앱 정보')),
    ],
  );
}
