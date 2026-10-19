import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'festival.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

/// 口令表：以后想加彩蛋，在这里加一条就行
String runCode(String raw) {
  final k = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (k == 'divine chinese chess') {
    if (app.hasDivine) return '该主题已解锁';
    app.change(() => app.unlocked.add('divine'));
    return '已解锁隐藏主题「神」和动态头像';
  }
  if (k == '投降') {
    if (!prank.active) return '今天不是愚人节，无需投降';
    prank.setHonest();
    return '好啦，这回我会乖乖的啦ᯠ  _   ̫  _ ̥ ᯄ ੭';
  }
  return '我没写过这个，是你输错了嘛？再核对一下试试ᯠ˶｡  ̫`｡˶ᯄ੭';
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
    await Clipboard.setData(ClipboardData(text: app.exportText()));
    _toast('数据已复制到剪贴板，请粘贴保存好');
  }

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr('导入会覆盖当前的资料、设置和战绩，确定继续？')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('取消'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('确定'))),
        ],
      ),
    );
    if (ok != true) return;
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final r = app.importText(d?.text ?? '');
    if (r == null) {
      _toast('导入成功');
    } else if (r == 'sig') {
      _toast('数据校验失败，可能被修改过');
    } else {
      _toast('剪贴板里没有有效数据');
    }
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
                  const SizedBox(height: 4),
                  Text(tr('点一下预览，再点一下取消'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 10),
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
                  Text(tr('战绩由联机对战自动记录，不能手动修改。'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  Text(tr('导出内容不含头像和图片。'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  if (app.tampered)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(tr('检测到战绩数据异常，已重置。'),
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
          ],
        );
      },
    );
  }
}
