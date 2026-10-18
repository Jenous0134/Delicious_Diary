import 'package:flutter/material.dart';

class UiPreview extends StatefulWidget {
  const UiPreview({super.key});
  @override
  State<UiPreview> createState() => _UiPreviewState();
}

class _UiPreviewState extends State<UiPreview> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['오늘도 맛있는 하루', '캘린더', '식사 기록 추가', '검색 및 필터', '더보기'][index]),
      ),
      body: IndexedStack(
        index: index,
        children: const [
          _PreviewHome(),
          _PreviewCalendar(),
          _PreviewAdd(),
          _PreviewSearch(),
          _PreviewMore(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => index = 2),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
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
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      _MealPreview(
        title: '점심 · 을지로 맛집',
        date: '2026년 10월 18일',
        icon: Icons.ramen_dining,
      ),
      SizedBox(height: 14),
      _MealPreview(
        title: '저녁 · 집',
        date: '2026년 10월 17일',
        icon: Icons.rice_bowl,
      ),
    ],
  );
}

class _MealPreview extends StatelessWidget {
  const _MealPreview({
    required this.title,
    required this.date,
    required this.icon,
  });
  final String title, date;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: ColoredBox(
            color: const Color(0xFFE8D8C4),
            child: Center(
              child: Icon(icon, size: 72, color: const Color(0xFF8B6545)),
            ),
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
                  fontSize: 17,
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

class _PreviewCalendar extends StatelessWidget {
  const _PreviewCalendar();
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
        const SizedBox(height: 24),
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

class _PreviewAdd extends StatelessWidget {
  const _PreviewAdd();
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
        decoration: InputDecoration(
          labelText: '날짜 *',
          hintText: '2026년 10월 18일',
        ),
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
      const TextField(decoration: InputDecoration(labelText: '장소 *')),
      const SizedBox(height: 12),
      const TextField(decoration: InputDecoration(labelText: '메뉴')),
    ],
  );
}

class _PreviewSearch extends StatelessWidget {
  const _PreviewSearch();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '메뉴, 장소, 메모 검색...',
        ),
      ),
      SizedBox(height: 20),
      Text('날짜'),
      Divider(),
      ListTile(title: Text('장소'), trailing: Text('전체  ›')),
      ListTile(title: Text('메뉴'), trailing: Text('전체  ›')),
      ListTile(title: Text('같이 먹은 사람'), trailing: Text('전체  ›')),
    ],
  );
}

class _PreviewMore extends StatelessWidget {
  const _PreviewMore();
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
