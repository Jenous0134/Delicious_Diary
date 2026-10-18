import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/design_system.dart';
import '../../core/file_storage/photo_storage_service.dart';
import '../meals/domain/meal.dart';
import '../meals/presentation/meal_state.dart';
import '../settings/presentation/settings_screen.dart';
import 'app_shell.dart' as legacy;

const _orange = AppColors.orange;
const _ink = AppColors.ink;
const _muted = AppColors.muted;
const _line = AppColors.line;

class ModernAppShell extends StatefulWidget {
  const ModernAppShell({super.key});

  @override
  State<ModernAppShell> createState() => _ModernAppShellState();
}

class _ModernAppShellState extends State<ModernAppShell> {
  int _index = 0;
  MealFilter _filter = const MealFilter();
  String _query = '';

  void _setFilter(MealFilter value) => setState(() => _filter = value);

  Future<void> _openSearch() async {
    final value = await showSearch<String>(
      context: context,
      delegate: _MealSearchDelegate(initial: _query),
    );
    if (value != null) setState(() => _query = value.trim());
  }

  Future<void> _openFilters() async {
    final value = await showModalBottomSheet<MealFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (value != null) _setFilter(value);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(
        filter: _filter,
        query: _query,
        onSearch: _openSearch,
        onFilter: _openFilters,
        onClearQuery: () => setState(() => _query = ''),
        onClearFilter: () => _setFilter(const MealFilter()),
      ),
      CalendarGalleryScreen(
        filter: _filter,
        query: _query,
        onSearch: _openSearch,
        onFilter: _openFilters,
      ),
      const SizedBox.shrink(),
      MealMapScreen(
        filter: _filter,
        query: _query,
        onSearch: _openSearch,
        onFilter: _openFilters,
      ),
      LibraryScreen(
        filter: _filter,
        query: _query,
        onSearch: _openSearch,
        onFilter: _openFilters,
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onChanged: (value) {
          if (value == 2) {
            legacy.openMealEditor(context);
          } else {
            setState(() => _index = value);
          }
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(5, (i) {
            if (i == 2) {
              return Expanded(
                child: Center(
                  child: IconButton.filled(
                    tooltip: '기록 추가',
                    onPressed: () => onChanged(2),
                    style: IconButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 29),
                  ),
                ),
              );
            }
            final selected = index == i;
            const labels = ['피드', '캘린더', '', '지도', '보관함'];
            const icons = [
              Icons.home_outlined,
              Icons.calendar_month_outlined,
              Icons.add,
              Icons.map_outlined,
              Icons.photo_library_outlined,
            ];
            const activeIcons = [
              Icons.home_rounded,
              Icons.calendar_month_rounded,
              Icons.add,
              Icons.map_rounded,
              Icons.photo_library_rounded,
            ];
            return Expanded(
              child: InkResponse(
                onTap: () => onChanged(i),
                child: Semantics(
                  selected: selected,
                  label: labels[i],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? activeIcons[i] : icons[i],
                        color: selected ? _orange : const Color(0xFF8A8A8A),
                        size: 23,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: selected ? _ink : const Color(0xFF8A8A8A),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class _ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ScreenHeader({
    required this.title,
    required this.onSearch,
    required this.onFilter,
    this.leadingLogo = false,
    this.extra,
  });
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final bool leadingLogo;
  final Widget? extra;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: false,
    titleSpacing: 18,
    title: Row(
      children: [
        if (leadingLogo) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/branding/logo.png',
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 9),
        ],
        Text(title),
      ],
    ),
    actions: [
      ?extra,
      IconButton(
        tooltip: '통합 검색',
        onPressed: onSearch,
        icon: const Icon(Icons.search_rounded),
      ),
      IconButton(
        tooltip: '필터',
        onPressed: onFilter,
        icon: const Icon(Icons.tune_rounded),
      ),
      const SizedBox(width: 6),
    ],
  );
}

List<Meal> _matchQuery(List<Meal> meals, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return meals;
  return meals.where((meal) {
    final values = <String>[
      meal.placeName,
      meal.placeAddress ?? '',
      meal.memo ?? '',
      meal.type.label,
      ...meal.people,
      ...meal.items.map((item) => item.name),
    ];
    return values.any((value) => value.toLowerCase().contains(q));
  }).toList();
}

bool _hasFilter(MealFilter value) =>
    value.startDate != null ||
    value.endDate != null ||
    (value.place?.isNotEmpty ?? false) ||
    (value.menu?.isNotEmpty ?? false) ||
    (value.person?.isNotEmpty ?? false) ||
    value.type != null;

class _ActiveChips extends StatelessWidget {
  const _ActiveChips({
    required this.filter,
    required this.query,
    this.onClearQuery,
    this.onClearFilter,
  });
  final MealFilter filter;
  final String query;
  final VoidCallback? onClearQuery;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty && !_hasFilter(filter)) return const SizedBox.shrink();
    final labels = <String>[
      if (filter.startDate != null || filter.endDate != null)
        '${filter.startDate == null ? '' : DateFormat('M.d').format(filter.startDate!)}–${filter.endDate == null ? '' : DateFormat('M.d').format(filter.endDate!)}',
      if (filter.place?.isNotEmpty ?? false) '장소 ${filter.place}',
      if (filter.menu?.isNotEmpty ?? false) '메뉴 ${filter.menu}',
      if (filter.person?.isNotEmpty ?? false) '동행 ${filter.person}',
      if (filter.type != null) filter.type!.label,
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        children: [
          if (query.isNotEmpty)
            _TinyChip(label: '“$query”', onDeleted: onClearQuery),
          ...labels.map((e) => _TinyChip(label: e, onDeleted: onClearFilter)),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, this.onDeleted});
  final String label;
  final VoidCallback? onDeleted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 15),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({
    super.key,
    required this.filter,
    required this.query,
    required this.onSearch,
    required this.onFilter,
    required this.onClearQuery,
    required this.onClearFilter,
  });
  final MealFilter filter;
  final String query;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onClearQuery;
  final VoidCallback onClearFilter;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool newestFirst = true;
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMealsProvider(widget.filter));
    return Scaffold(
      appBar: _ScreenHeader(
        title: '한끼일기',
        leadingLogo: true,
        onSearch: widget.onSearch,
        onFilter: widget.onFilter,
        extra: PopupMenuButton<bool>(
          tooltip: '정렬',
          icon: const Icon(Icons.swap_vert_rounded),
          onSelected: (value) => setState(() => newestFirst = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: true, child: Text('최신순')),
            PopupMenuItem(value: false, child: Text('과거순')),
          ],
        ),
      ),
      body: Column(
        children: [
          _ActiveChips(
            filter: widget.filter,
            query: widget.query,
            onClearQuery: widget.onClearQuery,
            onClearFilter: widget.onClearFilter,
          ),
          Expanded(
            child: async.when(
              loading: () => const _LoadingState(),
              error: (_, _) =>
                  _ErrorState(onRetry: () => ref.invalidate(mealsProvider)),
              data: (raw) {
                final items = _matchQuery(raw, widget.query).toList()
                  ..sort(
                    (a, b) => newestFirst
                        ? b.eatenDate.compareTo(a.eatenDate)
                        : a.eatenDate.compareTo(b.eatenDate),
                  );
                if (items.isEmpty) {
                  return _EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: raw.isEmpty ? '첫 한 끼를 남겨보세요' : '조건에 맞는 기록이 없어요',
                    message: raw.isEmpty
                        ? '사진 한 장으로 시작하면, 나만의 맛있는 아카이브가 만들어져요.'
                        : '검색어나 필터를 조금 바꿔보세요.',
                    action: raw.isEmpty
                        ? () => legacy.openMealEditor(context)
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(mealsProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (_, index) => FeedPost(meal: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FeedPost extends StatefulWidget {
  const FeedPost({super.key, required this.meal});
  final Meal meal;
  @override
  State<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<FeedPost> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openDetail(context, meal),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 11),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFFEEE7),
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: _orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('yyyy년 M월 d일').format(meal.eatenDate)} · ${meal.type.label}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFAAAAAA),
                ),
              ],
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: meal.photos.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (_, i) => _FoodImage(photo: meal.photos[i]),
              ),
              if (meal.photos.length > 1)
                Positioned(
                  right: 12,
                  top: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '${page + 1}/${meal.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meal.photos.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    meal.photos.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == page ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == page ? _orange : const Color(0xFFD7D7D7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              if (meal.photos.length > 1) const SizedBox(height: 10),
              if (meal.items.isNotEmpty)
                Text(
                  meal.items.map((e) => e.name).join(' · '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              if (meal.people.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  '함께  ${meal.people.join(', ')}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
              if (meal.memo?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  meal.memo!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class CalendarGalleryScreen extends ConsumerStatefulWidget {
  const CalendarGalleryScreen({
    super.key,
    required this.filter,
    required this.query,
    required this.onSearch,
    required this.onFilter,
  });
  final MealFilter filter;
  final String query;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  @override
  ConsumerState<CalendarGalleryScreen> createState() =>
      _CalendarGalleryScreenState();
}

class _CalendarGalleryScreenState extends ConsumerState<CalendarGalleryScreen> {
  DateTime focused = DateTime.now();
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMealsProvider(widget.filter));
    return Scaffold(
      appBar: _ScreenHeader(
        title: '캘린더',
        onSearch: widget.onSearch,
        onFilter: widget.onFilter,
      ),
      body: async.when(
        loading: () => const _LoadingState(),
        error: (_, _) =>
            _ErrorState(onRetry: () => ref.invalidate(mealsProvider)),
        data: (raw) {
          final meals = _matchQuery(raw, widget.query);
          final byDay = <DateTime, List<Meal>>{};
          for (final meal in meals) {
            final key = DateTime(
              meal.eatenDate.year,
              meal.eatenDate.month,
              meal.eatenDate.day,
            );
            byDay.putIfAbsent(key, () => []).add(meal);
          }
          final selectedMeals =
              byDay[DateTime(selected.year, selected.month, selected.day)] ??
              [];
          return Column(
            children: [
              _ActiveChips(filter: widget.filter, query: widget.query),
              TableCalendar<Meal>(
                locale: 'ko_KR',
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: focused,
                selectedDayPredicate: (day) => isSameDay(day, selected),
                eventLoader: (day) =>
                    byDay[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (day, focus) => setState(() {
                  selected = day;
                  focused = focus;
                }),
                onPageChanged: (day) => focused = day,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: '월'},
                rowHeight: 54,
                daysOfWeekHeight: 24,
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Color(0xFFFFE5D9),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('M월 d일 EEEE', 'ko_KR').format(selected),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => legacy.openMealEditor(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('기록 추가'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: selectedMeals.isEmpty
                    ? const _EmptyState(
                        icon: Icons.no_meals_outlined,
                        title: '이날의 기록이 없어요',
                        message: '먹었던 순간을 사진으로 남겨보세요.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: selectedMeals.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => _MealRow(meal: selectedMeals[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key,
    required this.filter,
    required this.query,
    required this.onSearch,
    required this.onFilter,
  });
  final MealFilter filter;
  final String query;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryMode { allPhotos, covers, menu, place, people }

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryMode mode = _LibraryMode.allPhotos;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMealsProvider(widget.filter));
    return Scaffold(
      appBar: _ScreenHeader(
        title: '보관함',
        onSearch: widget.onSearch,
        onFilter: widget.onFilter,
        extra: IconButton(
          tooltip: '설정 및 백업',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ),
      body: async.when(
        loading: () => const _LoadingState(),
        error: (_, _) =>
            _ErrorState(onRetry: () => ref.invalidate(mealsProvider)),
        data: (raw) {
          final meals = _matchQuery(raw, widget.query);
          return Column(
            children: [
              _ActiveChips(filter: widget.filter, query: widget.query),
              SizedBox(
                height: 45,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ModeChip(
                      '전체 사진',
                      _LibraryMode.allPhotos,
                      mode,
                      (v) => setState(() => mode = v),
                    ),
                    _ModeChip(
                      '대표 사진',
                      _LibraryMode.covers,
                      mode,
                      (v) => setState(() => mode = v),
                    ),
                    _ModeChip(
                      '메뉴별',
                      _LibraryMode.menu,
                      mode,
                      (v) => setState(() => mode = v),
                    ),
                    _ModeChip(
                      '장소별',
                      _LibraryMode.place,
                      mode,
                      (v) => setState(() => mode = v),
                    ),
                    _ModeChip(
                      '사람별',
                      _LibraryMode.people,
                      mode,
                      (v) => setState(() => mode = v),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent(meals)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(List<Meal> meals) {
    if (meals.isEmpty) {
      return const _EmptyState(
        icon: Icons.photo_library_outlined,
        title: '아직 사진이 없어요',
        message: '기록을 추가하면 음식 사진이 이곳에 모여요.',
      );
    }
    if (mode == _LibraryMode.menu ||
        mode == _LibraryMode.place ||
        mode == _LibraryMode.people) {
      final groups = <String, List<Meal>>{};
      for (final meal in meals) {
        final keys = mode == _LibraryMode.menu
            ? meal.items.map((e) => e.name)
            : mode == _LibraryMode.place
            ? [meal.placeName]
            : meal.people;
        for (final key in keys) {
          groups.putIfAbsent(key, () => []).add(meal);
        }
      }
      if (groups.isEmpty) {
        return const _EmptyState(
          icon: Icons.category_outlined,
          title: '분류할 정보가 없어요',
          message: '기록에 메뉴, 장소 또는 동행인을 입력해 보세요.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final entry = groups.entries.elementAt(index);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 56,
                child: _FoodImage(
                  photo: entry.value.first.photos.firstOrNull,
                  thumbnail: true,
                ),
              ),
            ),
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${entry.value.length}개의 식사 기록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _GroupGallery(title: entry.key, meals: entry.value),
              ),
            ),
          );
        },
      );
    }
    final entries = <({Meal meal, MealPhoto photo})>[];
    for (final meal in meals) {
      final photos = mode == _LibraryMode.covers
          ? meal.photos.take(1)
          : meal.photos;
      for (final photo in photos) {
        entries.add((meal: meal, photo: photo));
      }
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => _openPhotoViewer(context, entry.meal, entry.photo),
          child: Hero(
            tag: entry.photo.id,
            child: _FoodImage(photo: entry.photo, thumbnail: true),
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(this.label, this.value, this.selected, this.onSelected);
  final String label;
  final _LibraryMode value;
  final _LibraryMode selected;
  final ValueChanged<_LibraryMode> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: ChoiceChip(
      label: Text(label),
      selected: value == selected,
      onSelected: (_) => onSelected(value),
      showCheckmark: false,
    ),
  );
}

class MealMapScreen extends ConsumerWidget {
  const MealMapScreen({
    super.key,
    required this.filter,
    required this.query,
    required this.onSearch,
    required this.onFilter,
  });
  final MealFilter filter;
  final String query;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredMealsProvider(filter));
    return Scaffold(
      appBar: _ScreenHeader(
        title: '지도',
        onSearch: onSearch,
        onFilter: onFilter,
      ),
      body: async.when(
        loading: () => const _LoadingState(),
        error: (_, _) =>
            _ErrorState(onRetry: () => ref.invalidate(mealsProvider)),
        data: (raw) {
          final meals = _matchQuery(raw, query);
          final located = meals
              .where((m) => m.latitude != null && m.longitude != null)
              .toList();
          final missing = meals.length - located.length;
          final groups = _mapGroups(located);
          final center = groups.isEmpty
              ? const LatLng(37.5665, 126.9780)
              : groups.first.point;
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: groups.isEmpty ? 11 : 13,
                  minZoom: 5,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jenous.hankkidiary',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: groups
                        .map(
                          (group) => Marker(
                            point: group.point,
                            width: 54,
                            height: 54,
                            child: GestureDetector(
                              onTap: () =>
                                  _showPlaceSheet(context, group.meals),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: group.meals.length == 1
                                    ? const Icon(
                                        Icons.restaurant_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      )
                                    : Text(
                                        '${group.meals.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 10,
                child: _ActiveChips(filter: filter, query: query),
              ),
              if (missing > 0)
                Positioned(
                  left: 16,
                  bottom: 18,
                  child: ActionChip(
                    avatar: const Icon(Icons.location_off_outlined, size: 18),
                    label: Text('좌표 없는 기록 $missing개'),
                    onPressed: () => _showPlaceSheet(
                      context,
                      meals
                          .where(
                            (m) => m.latitude == null || m.longitude == null,
                          )
                          .toList(),
                    ),
                  ),
                ),
              if (groups.isEmpty)
                const Center(
                  child: _EmptyState(
                    icon: Icons.map_outlined,
                    title: '지도에 표시할 장소가 없어요',
                    message: '카카오 장소 검색으로 위치를 선택하면 지도에 표시돼요.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapGroup {
  const _MapGroup(this.point, this.meals);
  final LatLng point;
  final List<Meal> meals;
}

List<_MapGroup> _mapGroups(List<Meal> meals) {
  final values = <String, List<Meal>>{};
  for (final meal in meals) {
    final key =
        '${(meal.latitude! * 1000).round()}:${(meal.longitude! * 1000).round()}';
    values.putIfAbsent(key, () => []).add(meal);
  }
  return values.values
      .map(
        (items) => _MapGroup(
          LatLng(items.first.latitude!, items.first.longitude!),
          items,
        ),
      )
      .toList();
}

Future<void> _showPlaceSheet(BuildContext context, List<Meal> meals) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              meals.isEmpty ? '장소 정보 없음' : meals.first.placeName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${meals.length}번의 방문 기록',
              style: const TextStyle(color: _muted),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: meals.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) => _MealRow(meal: meals[i]),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 58,
        child: _FoodImage(photo: meal.photos.firstOrNull, thumbnail: true),
      ),
    ),
    title: Text(
      meal.items.isEmpty
          ? meal.placeName
          : meal.items.map((e) => e.name).join(', '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${DateFormat('yyyy.MM.dd').format(meal.eatenDate)} · ${meal.type.label}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _openDetail(context, meal),
  );
}

class _GroupGallery extends StatelessWidget {
  const _GroupGallery({required this.title, required this.meals});
  final String title;
  final List<Meal> meals;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: meals.length,
      itemBuilder: (_, i) => InkWell(
        onTap: () => _openDetail(context, meals[i]),
        child: _FoodImage(photo: meals[i].photos.firstOrNull, thumbnail: true),
      ),
    ),
  );
}

Future<void> _openDetail(BuildContext context, Meal meal) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => ModernMealDetailScreen(meal: meal)),
);

Future<void> _openPhotoViewer(
  BuildContext context,
  Meal meal,
  MealPhoto selected,
) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => _PhotoViewer(meal: meal, selected: selected),
  ),
);

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.meal, required this.selected});
  final Meal meal;
  final MealPhoto selected;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController controller = PageController(
    initialPage: widget.meal.photos.indexOf(widget.selected),
  );
  late int index = widget.meal.photos.indexOf(widget.selected);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1}/${widget.meal.photos.length}'),
    ),
    body: PageView.builder(
      controller: controller,
      itemCount: widget.meal.photos.length,
      onPageChanged: (value) => setState(() => index = value),
      itemBuilder: (_, i) => InteractiveViewer(
        child: Center(
          child: Hero(
            tag: widget.meal.photos[i].id,
            child: _FoodImage(
              photo: widget.meal.photos[i],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

class ModernMealDetailScreen extends ConsumerWidget {
  const ModernMealDetailScreen({super.key, required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(meal.placeName),
      actions: [
        IconButton(
          tooltip: '수정',
          onPressed: () async {
            await legacy.openMealEditor(context, meal: meal);
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.edit_outlined),
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value != 'delete') return;
            final yes = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('기록을 삭제할까요?'),
                content: const Text('앱에 보관된 사진도 함께 삭제됩니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            );
            if (yes == true) {
              await ref.read(mealRepositoryProvider).delete(meal.id);
              refreshMeals(ref);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      ],
    ),
    body: ListView(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: meal.photos.length,
            itemBuilder: (_, i) => _FoodImage(photo: meal.photos[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.items.isEmpty
                    ? meal.placeName
                    : meal.items.map((e) => e.name).join(' · '),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(meal.eatenDate)} · ${meal.type.label}${meal.eatenTime == null ? '' : ' · ${meal.eatenTime}'}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              _DetailLine(
                icon: Icons.place_outlined,
                title: meal.placeName,
                subtitle: meal.placeAddress,
              ),
              if (meal.people.isNotEmpty)
                _DetailLine(
                  icon: Icons.people_outline,
                  title: meal.people.join(', '),
                  subtitle: '함께 먹은 사람',
                ),
              if (meal.memo?.isNotEmpty == true)
                _DetailLine(
                  icon: Icons.notes_rounded,
                  title: meal.memo!,
                  subtitle: '메모',
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _orange, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (subtitle?.isNotEmpty == true)
                Text(
                  subtitle!,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FoodImage extends StatelessWidget {
  const _FoodImage({
    this.photo,
    this.thumbnail = false,
    this.fit = BoxFit.cover,
  });
  final MealPhoto? photo;
  final bool thumbnail;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final value = photo;
    if (value == null) {
      return const ColoredBox(
        color: Color(0xFFF2F2F2),
        child: Center(
          child: Icon(Icons.image_outlined, color: Color(0xFFBBBBBB)),
        ),
      );
    }
    if (value.relativePath.startsWith('asset:')) {
      return Image.asset(
        value.relativePath.substring(6),
        fit: fit,
        alignment: _sampleAlignment(value.sortOrder),
      );
    }
    final path = thumbnail && value.thumbnailRelativePath != null
        ? value.thumbnailRelativePath!
        : value.relativePath;
    return FutureBuilder<File>(
      future: PhotoStorageService().resolve(path),
      builder: (_, snapshot) => snapshot.hasData
          ? Image.file(
              snapshot.data!,
              fit: fit,
              errorBuilder: (_, _, _) => const _BrokenImage(),
            )
          : const ColoredBox(
              color: Color(0xFFF2F2F2),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}

Alignment _sampleAlignment(int order) => const [
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.bottomLeft,
  Alignment.bottomRight,
][order % 4];

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Center(child: Icon(Icons.broken_image_outlined)),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final MealFilter initial;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final place = TextEditingController(text: widget.initial.place);
  late final menu = TextEditingController(text: widget.initial.menu);
  late final person = TextEditingController(text: widget.initial.person);
  late DateTime? start = widget.initial.startDate;
  late DateTime? end = widget.initial.endDate;
  late MealType? type = widget.initial.type;
  @override
  void dispose() {
    place.dispose();
    menu.dispose();
    person.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: start == null || end == null
          ? null
          : DateTimeRange(start: start!, end: end!),
    );
    if (value != null) {
      setState(() {
        start = value.start;
        end = value.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '필터',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '여러 조건은 모두 만족하는 기록만 보여줍니다.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              start == null
                  ? '날짜 또는 기간'
                  : '${DateFormat('yyyy.MM.dd').format(start!)} – ${DateFormat('yyyy.MM.dd').format(end!)}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: place,
            decoration: const InputDecoration(
              labelText: '장소',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: menu,
            decoration: const InputDecoration(
              labelText: '메뉴',
              prefixIcon: Icon(Icons.restaurant_menu_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: person,
            decoration: const InputDecoration(
              labelText: '같이 먹은 사람',
              prefixIcon: Icon(Icons.people_outline),
            ),
          ),
          const SizedBox(height: 18),
          const Text('식사 구분', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: type == null,
                onSelected: (_) => setState(() => type = null),
                showCheckmark: false,
              ),
              ...MealType.values.map(
                (value) => ChoiceChip(
                  label: Text(value.label),
                  selected: type == value,
                  onSelected: (_) => setState(() => type = value),
                  showCheckmark: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const MealFilter()),
                  child: const Text('초기화'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    MealFilter(
                      startDate: start,
                      endDate: end,
                      place: place.text,
                      menu: menu.text,
                      person: person.text,
                      type: type,
                    ),
                  ),
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MealSearchDelegate extends SearchDelegate<String> {
  _MealSearchDelegate({required String initial}) {
    query = initial;
  }
  @override
  String get searchFieldLabel => '장소, 메뉴, 사람, 메모 검색';
  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => close(context, query));
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '모든 기록에서 한 번에 찾아보세요',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '장소명, 메뉴, 같이 먹은 사람과 메모를 검색합니다.',
          style: TextStyle(color: _muted),
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => close(context, query),
            icon: const Icon(Icons.search),
            label: Text('“$query” 검색'),
          ),
        ],
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 36),
        const SizedBox(height: 12),
        const Text('기록을 불러오지 못했습니다.'),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFFBBBBBB)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add),
              label: const Text('기록 추가'),
            ),
          ],
        ],
      ),
    ),
  );
}
