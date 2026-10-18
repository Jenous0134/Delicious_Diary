import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/file_storage/photo_storage_service.dart';
import '../meals/domain/meal.dart';
import '../meals/presentation/meal_state.dart';
import '../backup/data/backup_service.dart';
import '../places/data/place_search_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: const [
        HomeScreen(),
        CalendarScreen(),
        SizedBox(),
        SearchScreen(),
        MoreScreen(),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => openMealEditor(context),
      child: const Icon(Icons.add),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) {
        if (value == 2) {
          openMealEditor(context);
          return;
        }
        setState(() => index = value);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '홈',
        ),
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

Future<void> openMealEditor(BuildContext context, {Meal? meal}) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MealEditorScreen(meal: meal)));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Row(
          children: [
            Icon(Icons.rice_bowl_outlined, size: 23),
            SizedBox(width: 9),
            Text('오늘도 맛있는 하루'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
        ],
      ),
      body: meals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => ErrorView(
          message: '기록을 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(mealsProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyView(onAdd: () => openMealEditor(context))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(mealsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => i == 0
                      ? const _HomeFilters()
                      : MealCard(meal: items[i - 1]),
                ),
              ),
      ),
    );
  }
}

class _HomeFilters extends StatelessWidget {
  const _HomeFilters();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['전체', '아침', '점심', '저녁', '간식', '야식']
              .map(
                (label) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: label == '전체',
                    showCheckmark: false,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        '최근 식사',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera_back_outlined, size: 64),
          const SizedBox(height: 16),
          Text('아직 기록이 없어요', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('오늘의 한 끼를 사진과 함께 남겨보세요.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('첫 기록 추가'),
          ),
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MealDetailScreen(mealId: meal.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: _PhotoCollage(photos: meal.photos),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meal.type.label} · ${meal.placeName}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat('yyyy년 M월 d일').format(meal.eatenDate)),
                      if (meal.items.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          meal.items.map((e) => e.name).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF766A61),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (meal.photos.length > 1)
                  Chip(
                    avatar: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text('${meal.photos.length}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotoCollage extends StatelessWidget {
  const _PhotoCollage({required this.photos});
  final List<MealPhoto> photos;
  @override
  Widget build(BuildContext context) {
    if (photos.length <= 1) {
      return MealImage(
        photo: photos.firstOrNull,
        fit: BoxFit.cover,
        useThumbnail: true,
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: MealImage(
            photo: photos[0],
            fit: BoxFit.cover,
            useThumbnail: true,
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: MealImage(
                  photo: photos[1],
                  fit: BoxFit.cover,
                  useThumbnail: true,
                ),
              ),
              if (photos.length > 2) ...[
                const SizedBox(height: 3),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MealImage(
                        photo: photos[2],
                        fit: BoxFit.cover,
                        useThumbnail: true,
                      ),
                      if (photos.length > 3)
                        ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: Text(
                              '+${photos.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MealImage extends StatelessWidget {
  const MealImage({
    super.key,
    this.photo,
    this.fit = BoxFit.cover,
    this.useThumbnail = false,
  });
  final MealPhoto? photo;
  final BoxFit fit;
  final bool useThumbnail;
  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return const ColoredBox(
        color: Color(0xFFE7DED3),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    return FutureBuilder<File>(
      future: PhotoStorageService().resolve(
        useThumbnail && photo!.thumbnailRelativePath != null
            ? photo!.thumbnailRelativePath!
            : photo!.relativePath,
      ),
      builder: (context, snapshot) => snapshot.hasData
          ? Image.file(
              snapshot.data!,
              fit: fit,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            )
          : const ColoredBox(
              color: Color(0xFFE7DED3),
              child: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}

class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({super.key, this.meal});
  final Meal? meal;
  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _EditablePhoto {
  _EditablePhoto.existing(this.existing) : picked = null;
  _EditablePhoto.picked(this.picked) : existing = null;
  final MealPhoto? existing;
  final XFile? picked;
  String get key => existing?.id ?? picked!.path;
}

class _MenuEntryControllers {
  _MenuEntryControllers({String name = '', int? price}) {
    nameController.text = name;
    if (price != null) priceController.text = price.toString();
  }
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  final formKey = GlobalKey<FormState>(),
      place = TextEditingController(),
      memo = TextEditingController(),
      people = TextEditingController();
  late DateTime date;
  late MealType type;
  TimeOfDay? eatenTime;
  final photos = <_EditablePhoto>[];
  final menuEntries = <_MenuEntryControllers>[];
  List<String> placeSuggestions = const [], peopleSuggestions = const [];
  PlaceResult? mapPlace;
  bool saving = false;
  bool allowPop = false;
  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    photos.addAll(
      (m?.photos ?? const <MealPhoto>[]).map(_EditablePhoto.existing),
    );
    date = m?.eatenDate ?? DateTime.now();
    type = m?.type ?? MealType.lunch;
    if (m?.eatenTime != null) {
      final parts = m!.eatenTime!.split(':');
      eatenTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    place.text = m?.placeName ?? '';
    memo.text = m?.memo ?? '';
    menuEntries.addAll(
      (m?.items ?? const <MealItem>[]).map(
        (item) => _MenuEntryControllers(name: item.name, price: item.priceWon),
      ),
    );
    people.text = m?.people.join(', ') ?? '';
    if (m?.placeSource == 'map' &&
        m?.latitude != null &&
        m?.longitude != null) {
      mapPlace = PlaceResult(
        id: '',
        name: m!.placeName,
        address: m.placeAddress ?? '',
        latitude: m.latitude!,
        longitude: m.longitude!,
      );
    }
    _recoverLostPhotos();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final repository = ref.read(mealRepositoryProvider);
    final values = await Future.wait([
      repository.recentPlaces(),
      repository.recentPeople(),
    ]);
    if (mounted) {
      setState(() {
        placeSuggestions = values[0];
        peopleSuggestions = values[1];
      });
    }
  }

  Future<void> _recoverLostPhotos() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      final files = response.files;
      if (!response.isEmpty && files != null && mounted) {
        setState(() => photos.addAll(files.map(_EditablePhoto.picked)));
      }
    } catch (_) {
      // The form remains usable; the picker will surface a fresh error on retry.
    }
  }

  @override
  void dispose() {
    for (final c in [place, memo, people]) {
      c.dispose();
    }
    for (final entry in menuEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final value = await picker.pickImage(source: source);
      if (value != null) {
        setState(() => photos.add(_EditablePhoto.picked(value)));
      }
    } else {
      final values = await picker.pickMultiImage();
      setState(() => photos.addAll(values.map(_EditablePhoto.picked)));
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    if (photos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 한 장 이상 선택해 주세요.')));
      return;
    }
    setState(() => saving = true);
    try {
      final items = menuEntries
          .where((entry) => entry.nameController.text.trim().isNotEmpty)
          .map((entry) {
            final clean = entry.priceController.text.replaceAll(',', '').trim();
            return MealItem(
              name: entry.nameController.text.trim(),
              priceWon: clean.isEmpty ? null : int.parse(clean),
            );
          })
          .toList();
      await ref
          .read(mealRepositoryProvider)
          .save(
            MealDraft(
              id: widget.meal?.id,
              eatenDate: date,
              type: type,
              eatenTime: eatenTime == null
                  ? null
                  : '${eatenTime!.hour.toString().padLeft(2, '0')}:${eatenTime!.minute.toString().padLeft(2, '0')}',
              placeName: place.text,
              photoPaths: photos
                  .where((e) => e.picked != null)
                  .map((e) => e.picked!.path)
                  .toList(),
              existingPhotos: photos
                  .where((e) => e.existing != null)
                  .map((e) => e.existing!)
                  .toList(),
              orderedPhotoKeys: photos.map((e) => e.key).toList(),
              placeSource: mapPlace == null ? 'manual' : 'map',
              placeProvider: mapPlace == null ? null : 'kakao',
              placeProviderId: mapPlace?.id,
              placeAddress: mapPlace?.address,
              latitude: mapPlace?.latitude,
              longitude: mapPlace?.longitude,
              memo: memo.text,
              items: items,
              people: people.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            ),
          );
      refreshMeals(ref);
      if (mounted) {
        allowPop = true;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> requestPop() async {
    if (saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('작성 중인 내용을 버릴까요?'),
        content: const Text('저장하지 않은 변경 사항은 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      allowPop = true;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) requestPop();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? '식사 기록 추가' : '기록 수정'),
        actions: [
          TextButton(onPressed: saving ? null : save, child: const Text('저장')),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 132,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length + 1,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex >= photos.length || newIndex > photos.length) {
                    return;
                  }
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = photos.removeAt(oldIndex);
                    photos.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  if (index == photos.length) {
                    return SizedBox(
                      key: const ValueKey('add-photo'),
                      width: 118,
                      child: OutlinedButton(
                        onPressed: () => pick(ImageSource.gallery),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            Text('사진 추가'),
                          ],
                        ),
                      ),
                    );
                  }
                  final photo = photos[index];
                  return Padding(
                    key: ValueKey(photo.key),
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 118,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photo.existing != null)
                            MealImage(photo: photo.existing)
                          else
                            Image.file(
                              File(photo.picked!.path),
                              fit: BoxFit.cover,
                            ),
                          if (index == 0)
                            const Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: EdgeInsets.all(6),
                                child: Chip(label: Text('대표')),
                              ),
                            ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton.filled(
                              onPressed: () {
                                if (photos.length == 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('사진은 한 장 이상 필요합니다.'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => photos.removeAt(index));
                              },
                              icon: const Icon(Icons.close, size: 17),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('카메라로 촬영'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜 *'),
              subtitle: Text(DateFormat('yyyy년 M월 d일').format(date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: date,
                );
                if (d != null) setState(() => date = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('식사 시각'),
              subtitle: Text(eatenTime?.format(context) ?? '미입력'),
              trailing: eatenTime == null
                  ? const Icon(Icons.schedule_outlined)
                  : IconButton(
                      onPressed: () => setState(() => eatenTime = null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: eatenTime ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => eatenTime = picked);
              },
            ),
            const Text('식사 구분 *'),
            Wrap(
              spacing: 8,
              children: MealType.values
                  .map(
                    (e) => ChoiceChip(
                      label: Text(e.label),
                      selected: type == e,
                      onSelected: (_) => setState(() => type = e),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: place,
              onChanged: (_) => mapPlace = null,
              decoration: const InputDecoration(
                labelText: '장소 *',
                hintText: '집, 회사, 식당 이름',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '장소를 입력해 주세요.' : null,
            ),
            if (placeSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: placeSuggestions
                        .take(6)
                        .map(
                          (value) => ActionChip(
                            label: Text(value),
                            onPressed: () => setState(() {
                              mapPlace = null;
                              place.text = value;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<PlaceResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlaceSearchScreen(),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      mapPlace = result;
                      place.text = result.name;
                    });
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('지도에서 장소 검색'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '메뉴와 가격',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => menuEntries.add(_MenuEntryControllers())),
                  icon: const Icon(Icons.add),
                  label: const Text('메뉴 추가'),
                ),
              ],
            ),
            for (var i = 0; i < menuEntries.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: menuEntries[i].nameController,
                      decoration: InputDecoration(labelText: '메뉴 ${i + 1}'),
                      validator: (value) {
                        final priceText = menuEntries[i].priceController.text
                            .trim();
                        if ((value == null || value.trim().isEmpty) &&
                            priceText.isNotEmpty) {
                          return '가격만 입력할 수 없습니다.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: menuEntries[i].priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '가격',
                        suffixText: '원',
                      ),
                      validator: (value) {
                        final clean = value?.replaceAll(',', '').trim() ?? '';
                        if (clean.isEmpty) return null;
                        final parsed = int.tryParse(clean);
                        if (parsed == null || parsed < 0) return '0 이상의 숫자';
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final removed = menuEntries.removeAt(i);
                      removed.dispose();
                      setState(() {});
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: people,
              decoration: const InputDecoration(
                labelText: '같이 먹은 사람',
                hintText: '쉼표로 여러 사람 구분',
              ),
            ),
            if (peopleSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: peopleSuggestions
                        .take(8)
                        .map(
                          (value) => ActionChip(
                            label: Text(value),
                            onPressed: () {
                              final current = people.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toSet();
                              current.add(value);
                              people.text = current.join(', ');
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: memo,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : save,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(saving ? '저장 중...' : '기록 저장'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});
  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final query = TextEditingController();
  final service = KakaoPlaceSearchService();
  List<PlaceResult> results = const [];
  bool loading = false;
  String? error;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    FocusScope.of(context).unfocus();
    if (query.text.trim().isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await service.search(query.text);
      if (mounted) setState(() => results = values);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Bad state: ', '');
          results = const [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> confirmPlace(PlaceResult place) async {
    final uri = Uri.https('dapi.kakao.com', '/v2/maps/staticmap', {
      'center': '${place.longitude},${place.latitude}',
      'markers': '${place.longitude},${place.latitude}',
      'size': '640x320',
    });
    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Image.network(
                    uri.toString(),
                    headers: {'Authorization': 'KakaoAK ${service.apiKey}'},
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFECE6DE),
                      child: Center(child: Text('지도 이미지를 불러오지 못했습니다.')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                place.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(place.address),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.location_on),
                label: const Text('이 장소로 선택'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == true && mounted) Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('장소 검색')),
    body: !service.isConfigured
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.key_off_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    '지도 API 설정이 필요합니다',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'KAKAO_REST_API_KEY가 없습니다. 뒤로 돌아가 장소를 직접 입력해 주세요. 가짜 검색 결과는 표시하지 않습니다.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => search(),
                  decoration: InputDecoration(
                    hintText: '식당이나 장소 이름',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: results.isEmpty && !loading && error == null
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = results[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(place.name),
                            subtitle: Text(place.address),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => confirmPlace(place),
                          );
                        },
                      ),
              ),
            ],
          ),
  );
}

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final String mealId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Meal?>(
    future: ref.read(mealRepositoryProvider).byId(mealId),
    builder: (context, snapshot) {
      final meal = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (meal == null) {
        return const Scaffold(body: Center(child: Text('기록을 찾을 수 없습니다.')));
      }
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () async {
                await openMealEditor(context, meal: meal);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('기록을 삭제할까요?'),
                    content: const Text('앱에 복사된 사진도 함께 삭제됩니다.'),
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
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: ListView(
          children: [
            SizedBox(
              height: 320,
              child: PageView(
                children: meal.photos
                    .map(
                      (p) => InteractiveViewer(
                        child: MealImage(photo: p, fit: BoxFit.contain),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meal.type.label} · ${meal.placeName}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(DateFormat('yyyy년 M월 d일').format(meal.eatenDate)),
                  const Divider(height: 32),
                  InfoLine(
                    '메뉴',
                    meal.items.isEmpty
                        ? '미입력'
                        : meal.items
                              .map(
                                (e) => e.priceWon == null
                                    ? e.name
                                    : '${e.name} ${NumberFormat('#,###').format(e.priceWon)}원',
                              )
                              .join(', '),
                  ),
                  InfoLine(
                    '같이 먹은 사람',
                    meal.people.isEmpty ? '미입력' : meal.people.join(', '),
                  ),
                  InfoLine(
                    '메모',
                    meal.memo?.isNotEmpty == true ? meal.memo! : '미입력',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime focused = DateTime.now(), selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('캘린더')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => ErrorView(
          message: '달력을 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(mealsProvider),
        ),
        data: (meals) {
          List<Meal> events(DateTime d) =>
              meals.where((m) => isSameDay(m.eatenDate, d)).toList();
          final day = events(selected);
          return Column(
            children: [
              TableCalendar<Meal>(
                locale: 'ko_KR',
                firstDay: DateTime(2000),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: focused,
                selectedDayPredicate: (d) => isSameDay(d, selected),
                eventLoader: events,
                calendarBuilders: CalendarBuilders<Meal>(
                  markerBuilder: (context, day, dayEvents) {
                    if (dayEvents.isEmpty || dayEvents.first.photos.isEmpty) {
                      return null;
                    }
                    return Positioned(
                      right: 1,
                      bottom: 1,
                      child: ClipOval(
                        child: SizedBox.square(
                          dimension: 22,
                          child: MealImage(
                            photo: dayEvents.first.photos.first,
                            useThumbnail: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                onDaySelected: (s, f) => setState(() {
                  selected = s;
                  focused = f;
                }),
                onPageChanged: (f) => focused = f,
              ),
              const Divider(),
              Expanded(
                child: day.isEmpty
                    ? const Center(child: Text('이 날짜에는 기록이 없습니다.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: day.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => MealCard(meal: day[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final place = TextEditingController(),
      menu = TextEditingController(),
      person = TextEditingController();
  MealType? type;
  DateTime? startDate, endDate;
  MealFilter filter = const MealFilter();
  @override
  void dispose() {
    place.dispose();
    menu.dispose();
    person.dispose();
    super.dispose();
  }

  void apply() => setState(
    () => filter = MealFilter(
      place: place.text,
      menu: menu.text,
      person: person.text,
      type: type,
      startDate: startDate,
      endDate: endDate,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(filteredMealsProvider(filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text('검색 및 필터'),
        actions: [
          TextButton(
            onPressed: () {
              place.clear();
              menu.clear();
              person.clear();
              setState(() {
                type = null;
                startDate = null;
                endDate = null;
                filter = const MealFilter();
              });
            },
            child: const Text('초기화'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: startDate == null || endDate == null
                            ? null
                            : DateTimeRange(start: startDate!, end: endDate!),
                      );
                      if (range != null) {
                        setState(() {
                          startDate = range.start;
                          endDate = range.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      startDate == null
                          ? '날짜 · 전체'
                          : '${DateFormat('yyyy.MM.dd').format(startDate!)} ~ ${DateFormat('yyyy.MM.dd').format(endDate!)}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: place,
                  decoration: const InputDecoration(labelText: '장소'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: menu,
                  decoration: const InputDecoration(labelText: '메뉴'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: person,
                  decoration: const InputDecoration(labelText: '같이 먹은 사람'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MealType?>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '식사 구분'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    ...MealType.values.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    ),
                  ],
                  onChanged: (v) => setState(() => type = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: apply,
                    child: const Text('검색하기'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const Center(child: Text('검색하지 못했습니다.')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('조건에 맞는 기록이 없습니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => MealCard(meal: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});
  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool exporting = false;
  bool restoring = false;
  Future<void> exportBackup() async {
    setState(() => exporting = true);
    try {
      final file = await BackupService().createBackup();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '한끼일기 백업',
          text: '한끼일기 기록과 사진 백업 파일입니다.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('백업 파일을 만들었습니다. 저장할 앱이나 위치를 선택해 주세요.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('백업하지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> restoreBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked.firstOrNull?.path;
    if (path == null || !mounted) return;
    setState(() => restoring = true);
    try {
      final service = BackupService();
      final summary = await service.inspectBackup(File(path));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('백업에서 복원할까요?'),
          content: Text(
            '식사 ${summary.meals}개와 사진 ${summary.photos}개를 복원합니다.\n\n현재 기록은 모두 대체됩니다. 복원에 실패하면 현재 데이터가 유지됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('전체 대체'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final restored = await service.restoreBackup(File(path));
      refreshMeals(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '식사 ${restored.meals}개와 사진 ${restored.photos}개를 복원했습니다.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원하지 못했습니다. 현재 기록은 유지됩니다.\n$error')),
        );
      }
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('더보기')),
    body: ListView(
      children: [
        ListTile(
          leading: Icon(Icons.backup_outlined),
          title: const Text('ZIP 백업'),
          subtitle: Text(
            exporting ? '백업 파일을 만드는 중입니다...' : '기록과 원본 사진을 ZIP으로 내보내기',
          ),
          trailing: exporting
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: exporting ? null : exportBackup,
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('ZIP에서 복원'),
          subtitle: Text(
            restoring ? '백업 파일을 검사하는 중입니다...' : '검증 후 기존 기록 전체 대체',
          ),
          trailing: restoring
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: restoring ? null : restoreBackup,
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('데이터 보관 안내'),
          subtitle: Text('사진과 기록은 이 기기의 앱 전용 저장소에 보관됩니다. 앱 삭제 전 백업이 필요합니다.'),
        ),
        const ListTile(
          leading: Icon(Icons.palette_outlined),
          title: Text('브랜딩'),
          subtitle: Text('제공된 한끼일기 로고와 앱 아이콘을 사용합니다.'),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('앱 정보'),
          subtitle: Text('한끼일기 0.1.0'),
        ),
      ],
    ),
  );
}
