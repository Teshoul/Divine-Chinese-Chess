import 'package:flutter/material.dart';
import 'backup.dart';
import 'festival.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

/// 开发者口令只存校验值，不存明文
const String kDevHash = '4390a8d6071ddb3a';
bool isDevCode(String raw) => signText('dev|${raw.trim()}') == kDevHash;

/// 口令表：以后想加彩蛋，在这里加一条就行
String runCode(String raw) {
  if (isDevCode(raw)) {
    if (app.dev) return '已在开发者模式中';
    app.enterDev();
    return '已进入开发者模式，全部道具已发放';
  }
  final k = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (k == 'divine chinese chess') {
    if (app.hasDivine && app.owns('badge_divine')) return '该主题已解锁';
    app.unlockDivine();
    return '已解锁隐藏主题「神」和动态头像';
  }
  if (k == '投降') {
    if (!prank.active) return '今天不是愚人节，无需投降';
    prank.setHonest();
    return '口令生效：白旗这次会老实让你点';
  }
  return '口令无效';
}

class ExtrasSections extends StatefulWidget {
  const ExtrasSections({super.key});
  @override
  State<ExtrasSections> createState() => _ExtrasSectionsState();
}

class _ExtrasSectionsState extends State<ExtrasSections> {
  final TextEditingController c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _toast(String zh) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(zh))));
  }

  void _run() {
    final r = runCode(c.text);
    c.clear();
    FocusScope.of(context).unfocus();
    _toast(r);
  }

  void _preview(String id) {
    app.change(() {
      app.festPreview = id;
      if (id == 'april') app.prankOff = '';
    });
    prank.reset();
  }

  Future<void> _export() async {
    final r = await exportBackup(context);
    if (!mounted) return;
    if (r == 'ok') _toast('备份已保存');
    if (r == 'fail') _toast('导出失败');
  }

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr('导入会覆盖当前的资料、设置、战绩、头像和音乐，确定继续？')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('取消'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('确定'))),
        ],
      ),
    );
    if (ok != true) return;
    final r = await importBackup();
    if (!mounted) return;
    if (r == 'ok') _toast('导入成功');
    if (r == 'sig') _toast('数据校验失败，可能被修改过');
    if (r == 'bad') _toast('导入失败：文件不是有效的备份压缩包');
  }

  Widget _card(String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _devCard(ColorScheme cs) {
    return _card(
      '开发者选项',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('开发者模式已开启'),
              style: TextStyle(color: app.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(tr('点击战绩数字可修改（仅开发者）'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 14),
          Text(tr('节日预览'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(tr('点一下预览，再点一下取消'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in kFestivals)
                LitToggle(
                  wide: true,
                  label: tr(f.name),
                  value: app.festPreview == f.id,
                  onChanged: (v) => _preview(v ? f.id : ''),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  app.change(() => app.grantAll());
                  _toast('道具已发放');
                },
                icon: const Icon(Icons.inventory_2),
                label: Text(tr('重新发放全部道具')),
              ),
              OutlinedButton.icon(
                onPressed: () => app.exitDev(),
                icon: const Icon(Icons.logout),
                label: Text(tr('退出开发者模式')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('未来的测试功能会出现在这里'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final today = detectFestival(DateTime.now());
        return Column(
          children: [
            const Center(child: PrankFlagHost(at: 'settings')),
            _card(
              '节日彩蛋',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LitToggle(
                    wide: true,
                    icon: Icons.celebration,
                    label: tr('节日彩蛋'),
                    value: app.festOn,
                    onChanged: (v) => app.change(() => app.festOn = v),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    today != null
                        ? trf('今天是{f}', {'f': tr(today.name)})
                        : tr('今天没有节日'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _card(
              '口令',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: c,
                    onSubmitted: (_) => _run(),
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: tr('输入口令'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _run, child: Text(tr('执行'))),
                  ),
                ],
              ),
            ),
            _card(
              '玩家数据',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('战绩由联机对战自动记录，不能手动修改'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                      tr('导出的压缩包包含头像、头像库、装扮道具、自定义颜色、背景图和音乐；战绩带校验码，被改动的备份无法导入。'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  if (app.tampered)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(tr('你偷偷改数据了对吧ᯠ˶｡  ̫`｡˶ᯄ੭'),
                          style: TextStyle(color: cs.error, fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.upload),
                        label: Text(tr('导出数据')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.download),
                        label: Text(tr('导入数据')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (app.dev) _devCard(cs),
          ],
        );
      },
    );
  }
}
