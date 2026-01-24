import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'wordpress_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PambiancoApp());
  if (kIsWeb) {
    html.window.console.log('BUILD_VERIFIED_2026_01_24_17_38');
  }
}

class PambiancoApp extends StatelessWidget {
  const PambiancoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAMBIANCO DIGIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFFE5E5E5),
          surface: Color(0xFF1A1A1A),
        ),
      ),
      home: const MagazineScreen(),
    );
  }
}

// --- MODELS ---

enum PageType { cover, toc, article, adv }
enum ArticleLayoutType { standard, split, quote, fullImage }

class NewsItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? category;
  final String? author;
  final String? content;
  final String? imageUrl;
  final String? quote;
  final PageType type;
  final ArticleLayoutType layoutType;
  final DateTime date;
  final List<NewsItem>? childItems;
  final String? pdfUrl;

  NewsItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.category,
    this.author,
    this.content,
    this.imageUrl,
    this.quote,
    required this.type,
    this.layoutType = ArticleLayoutType.standard,
    required this.date,
    this.childItems,
    this.pdfUrl,
  });

  factory NewsItem.fromWordPress(Map<String, dynamic> json, {String portalName = 'MODA'}) {
    String? imageUrl;
    try {
      if (json['_embedded'] != null && 
          json['_embedded']['wp:featuredmedia'] != null && 
          json['_embedded']['wp:featuredmedia'] is List &&
          json['_embedded']['wp:featuredmedia'].isNotEmpty) {
        imageUrl = json['_embedded']['wp:featuredmedia'][0]['source_url'];
      }
    } catch (e) {}

    if (portalName == 'MAGAZINE' && json['meta'] != null) {
      if (json['meta']['thumbnail'] != null) imageUrl = json['meta']['thumbnail'];
    }

    if (imageUrl != null && kIsWeb) {
      imageUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=1000';
    }

    final layouts = [ArticleLayoutType.standard, ArticleLayoutType.standard, ArticleLayoutType.quote];
    final idStr = json['id']?.toString() ?? '0';
    final layoutType = layouts[int.parse(idStr) % layouts.length];

    String? authorName;
    try {
      if (json['_embedded'] != null && 
          json['_embedded']['author'] != null && 
          json['_embedded']['author'] is List &&
          json['_embedded']['author'].isNotEmpty) {
        authorName = json['_embedded']['author'][0]['name'];
      }
    } catch (e) {}

    return NewsItem(
      id: idStr,
      title: _clean(json['title']?['rendered'] ?? 'Senza Titolo'),
      subtitle: _clean(json['excerpt']?['rendered'] ?? ''),
      category: portalName == 'MAGAZINE' ? 'MAGAZINE' : (portalName == 'WINE&FOOD' ? 'WINE&FOOD' : (portalName == 'HOTELLERIE' ? 'HOTELLERIE' : portalName)),
      author: authorName ?? 'Redazione Pambianco',
      content: _clean(json['content']?['rendered'] ?? ''),
      imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1511467687858-23d96c32e4ae?q=80&w=2070&auto=format&fit=crop',
      type: PageType.article,
      layoutType: layoutType,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      quote: layoutType == ArticleLayoutType.quote ? _clean(json['title']?['rendered'] ?? '') : null,
      pdfUrl: json['meta'] != null ? json['meta']['magazine_pdf'] ?? json['meta']['pdf_url'] : null,
    );
  }

  static String _clean(String? html) {
    if (html == null) return '';
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').replaceAll('[&hellip;]', '...').trim();
  }
}

// --- MAIN SCREEN ---

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  List<NewsItem> _dynamicData = [
    NewsItem(
      id: '0',
      title: 'PAMBIANCO\nDIGIT',
      subtitle: 'The Future of Digital Luxury',
      type: PageType.cover,
      date: DateTime.now(),
    ),
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
    _fetchAllLiveContent();
  }

  Future<void> _fetchAllLiveContent() async {
    setState(() => _isLoading = true);
    try {
      final service = WordPressService();
      final portals = ['MODA', 'DESIGN', 'BEAUTY', 'WINE&FOOD', 'HOTELLERIE', 'MAGAZINE'];
      
      for (String portal in portals) {
        final articles = await service.fetchArticlesForPortal(portal);
        if (articles.isNotEmpty) {
          setState(() {
            if (_dynamicData[0].imageUrl == null && articles[0].imageUrl != null) {
              _dynamicData[0] = NewsItem(
                id: _dynamicData[0].id,
                title: _dynamicData[0].title,
                subtitle: _dynamicData[0].subtitle,
                type: _dynamicData[0].type,
                date: _dynamicData[0].date,
                imageUrl: articles[0].imageUrl,
              );
            }
            _dynamicData.addAll(articles);
          });
        }
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEdicolaGrid(BuildContext context, List<NewsItem> magazinesList) {
    if (magazinesList.isEmpty) return;
    
    final Map<String, NewsItem> latestByCategory = {};
    for (var mag in magazinesList) {
      String group = 'General';
      if (mag.title.contains('Beauty')) group = 'Beauty';
      else if (mag.title.contains('Design')) group = 'Design';
      else if (mag.title.contains('Hotellerie')) group = 'Hotellerie';
      else if (mag.title.contains('Magazine')) group = 'Magazine';
      if (!latestByCategory.containsKey(group)) latestByCategory[group] = mag;
    }
    
    final displayMagazines = latestByCategory.values.toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('EDICOLA', style: GoogleFonts.bodoniModa(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: displayMagazines.length,
                itemBuilder: (context, index) {
                  final mag = displayMagazines[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (mag.pdfUrl != null) _openPdf(context, mag.pdfUrl!, mag.title);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              image: mag.imageUrl != null ? DecorationImage(image: NetworkImage(mag.imageUrl!), fit: BoxFit.cover) : null,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(mag.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.bodoniModa(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPdf(BuildContext context, String url, String title) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfUrl: url, title: title)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _dynamicData.length,
            itemBuilder: (context, index) {
              final double difference = index - _currentPage;
              return MagazinePage(
                item: _dynamicData[index],
                parallaxRatio: difference,
                controller: _pageController,
              );
            },
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GlassDock(
                onCategoryTap: (category) {
                  if (category == 'MAGAZINE') {
                    _showEdicolaGrid(context, _dynamicData.where((e) => e.category == 'MAGAZINE').toList());
                  } else {
                    int targetIndex = _dynamicData.indexWhere((e) => e.category == category);
                    if (targetIndex != -1) {
                      _pageController.animateToPage(targetIndex, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
                    }
                  }
                },
                magazines: _dynamicData.where((item) => item.category == 'MAGAZINE').toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAGE COMPONENTS ---

class MagazinePage extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  final PageController controller;

  const MagazinePage({super.key, required this.item, required this.parallaxRatio, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(parallaxRatio * 0.1),
      alignment: Alignment.center,
      child: Container(decoration: const BoxDecoration(color: Color(0xFF0A0A0A)), child: _buildLayout(context)),
    );
  }

  Widget _buildLayout(BuildContext context) {
    switch (item.type) {
      case PageType.cover: return _CoverLayout(item: item);
      case PageType.article: return _ArticleDispatcher(item: item, parallaxRatio: parallaxRatio, controller: controller);
      case PageType.adv: return _AdvLayout(item: item);
      default: return const SizedBox.shrink();
    }
  }
}

class _CoverLayout extends StatelessWidget {
  final NewsItem item;
  const _CoverLayout({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: item.imageUrl != null ? Image.network(item.imageUrl!, fit: BoxFit.cover) : Container(color: const Color(0xFF1A1A1A)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(153), Colors.transparent, Colors.black.withAlpha(204)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('EDIZIONE DEL GIORNO', style: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 4, color: const Color(0xFFD4AF37), fontWeight: FontWeight.w600)),
              const SizedBox(height: 15),
              Text('PAMBIANCO\nDIGIT', style: GoogleFonts.bodoniModa(fontSize: 72, fontWeight: FontWeight.w900, height: 0.85, letterSpacing: -2)),
              const SizedBox(height: 20),
              Text('${item.date.day} GENNAIO 2026', style: GoogleFonts.spaceMono(fontSize: 14, letterSpacing: 3, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArticleDispatcher extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  final PageController controller;
  const _ArticleDispatcher({required this.item, required this.parallaxRatio, required this.controller});

  @override
  Widget build(BuildContext context) {
    switch (item.layoutType) {
      case ArticleLayoutType.quote: return _ArticleQuoteLayout(item: item, parallaxRatio: parallaxRatio);
      case ArticleLayoutType.fullImage: return _ArticleFullImageLayout(item: item, parallaxRatio: parallaxRatio);
      default: return _ArticleStandardLayout(item: item, parallaxRatio: parallaxRatio);
    }
  }
}

class _ArticleStandardLayout extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  const _ArticleStandardLayout({required this.item, required this.parallaxRatio});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: Transform.translate(offset: Offset(parallaxRatio * 50, 0), child: Image.network(item.imageUrl!, fit: BoxFit.cover))),
                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [const Color(0xFF0A0A0A), Colors.transparent]))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(item.category ?? '', style: GoogleFonts.spaceMono(fontSize: 12, letterSpacing: 3, color: const Color(0xFFD4AF37))),
                const SizedBox(height: 10),
                Text(item.title, style: GoogleFonts.bodoniModa(fontSize: 34, height: 1.1, fontWeight: FontWeight.w700)),
                const SizedBox(height: 15),
                Text(item.subtitle ?? '', style: GoogleFonts.inter(fontSize: 18, color: Colors.white70)),
                const SizedBox(height: 25),
                Text(item.content ?? '', style: GoogleFonts.inter(fontSize: 16, height: 1.6, color: Colors.white.withAlpha(217))),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleQuoteLayout extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  const _ArticleQuoteLayout({required this.item, required this.parallaxRatio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.format_quote, size: 60, color: Color(0xFFD4AF37)),
          const SizedBox(height: 20),
          Text(item.quote ?? item.title, textAlign: TextAlign.center, style: GoogleFonts.bodoniModa(fontSize: 26, fontStyle: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 20),
          Text(item.author?.toUpperCase() ?? 'REDAZIONE', style: GoogleFonts.spaceMono(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ArticleFullImageLayout extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  const _ArticleFullImageLayout({required this.item, required this.parallaxRatio});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.network(item.imageUrl!, fit: BoxFit.cover)),
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.category?.toUpperCase() ?? '', style: GoogleFonts.spaceMono(fontSize: 12, letterSpacing: 4, color: const Color(0xFFD4AF37))),
              const SizedBox(height: 15),
              Text(item.title, style: GoogleFonts.bodoniModa(fontSize: 42, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text(item.content ?? '', style: GoogleFonts.inter(fontSize: 16, height: 1.6, color: Colors.white70), maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvLayout extends StatelessWidget {
  final NewsItem item;
  const _AdvLayout({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.network(item.imageUrl!, height: double.infinity, width: double.infinity, fit: BoxFit.cover),
        Container(color: Colors.black45),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PARTNER CONTENT', style: GoogleFonts.spaceMono(fontSize: 10, letterSpacing: 4)),
              const SizedBox(height: 40),
              Text(item.title, textAlign: TextAlign.center, style: GoogleFonts.bodoniModa(fontSize: 40)),
            ],
          ),
        ),
      ],
    );
  }
}

class GlassDock extends StatelessWidget {
  final Function(String) onCategoryTap;
  final List<NewsItem> magazines;

  const GlassDock({super.key, required this.onCategoryTap, required this.magazines});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DockIcon(icon: Icons.checkroom, label: 'MODA', onTap: () => onCategoryTap('MODA')),
                _DockIcon(icon: Icons.chair, label: 'DESIGN', onTap: () => onCategoryTap('DESIGN')),
                _DockIcon(icon: Icons.face, label: 'BEAUTY', onTap: () => onCategoryTap('BEAUTY')),
                _DockIcon(icon: Icons.restaurant, label: 'WINE&FOOD', onTap: () => onCategoryTap('WINE&FOOD')),
                _DockIcon(icon: Icons.hotel, label: 'HOTELLERIE', onTap: () => onCategoryTap('HOTELLERIE')),
                _DockIcon(icon: Icons.picture_as_pdf, label: 'MAGAZINE', onTap: () => onCategoryTap('MAGAZINE')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.spaceMono(fontSize: 9, letterSpacing: 1, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerPage({super.key, required this.pdfUrl, required this.title});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final safeUrl = widget.pdfUrl.contains('#toolbar=0') ? widget.pdfUrl : '${widget.pdfUrl}#toolbar=0';
      ui_web.platformViewRegistry.registerViewFactory(
        'pdf-viewer-${widget.pdfUrl.hashCode}',
        (int viewId) => html.IFrameElement()
          ..src = safeUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(widget.title, style: GoogleFonts.bodoniModa(fontSize: 16)),
      ),
      body: kIsWeb 
        ? HtmlElementView(viewType: 'pdf-viewer-${widget.pdfUrl.hashCode}')
        : SfPdfViewer.network(widget.pdfUrl),
    );
  }
}
