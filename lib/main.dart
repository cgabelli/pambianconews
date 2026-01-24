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
}

class PambiancoApp extends StatelessWidget {
  const PambiancoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Register the PDF iframe for Web
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        'pdf-viewer-html',
        (int viewId) => html.IFrameElement()

          ..src = 'https://magazine.pambianconews.com/wp-content/uploads/sites/8/2025/12/Pambianco-Magazine-n1_2026.pdf'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }

    return MaterialApp(
      title: 'PAMBIANCO DIGIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), // Burnished Gold
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
  final List<NewsItem>? childItems; // For internal index navigation
  final String? pdfUrl; // For magazines

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

  factory NewsItem.fromWordPress(Map<String, dynamic> json) {
    String? imageUrl;
    try {
      if (json['_embedded'] != null && 
          json['_embedded']['wp:featuredmedia'] != null && 
          json['_embedded']['wp:featuredmedia'] is List &&
          json['_embedded']['wp:featuredmedia'].isNotEmpty) {
        imageUrl = json['_embedded']['wp:featuredmedia'][0]['source_url'];
      }
    } catch (e) {
      print('Error parsing WP image: $e');
    }

    // Check for Magazine thumbnail specifically
    if (portalName == 'MAGAZINE' && json['meta'] != null) {
      if (json['meta']['thumbnail'] != null) imageUrl = json['meta']['thumbnail'];
      if (json['meta']['_thumbnail'] != null) imageUrl = json['meta']['_thumbnail'];
    }

    // CORS Proxy for Web development
    if (imageUrl != null && kIsWeb) {
      imageUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=1000';
    }

    final layouts = [ArticleLayoutType.standard, ArticleLayoutType.standard, ArticleLayoutType.quote]; // Removed split
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
    } catch (e) {
      print('Error parsing author: $e');
    }

    return NewsItem(
      id: idStr,
      title: _clean(json['title']?['rendered'] ?? 'Senza Titolo'),
      subtitle: _clean(json['excerpt']?['rendered'] ?? ''),
      category: portalName == 'WINE&FOOD' ? 'WINE&FOOD' : (portalName == 'HOTELLERIE' ? 'HOTELLERIE' : portalName),
      author: authorName ?? 'Redazione Pambianco',
      content: _clean(json['content']?['rendered'] ?? ''),
      imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1511467687858-23d96c32e4ae?q=80&w=2070&auto=format&fit=crop',
      type: PageType.article,
      layoutType: layoutType,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      quote: layoutType == ArticleLayoutType.quote ? _clean(json['title']?['rendered'] ?? '') : null,
      pdfUrl: json['meta'] != null ? json['meta']['magazine_pdf'] ?? json['meta']['pdf_url'] : null, // Attempt to get PDF from meta
    );
  }

  static String _clean(String? html) {
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '')
        .replaceAll('[&hellip;]', '...')
        .trim();
  }
}


// --- DATA MOCK ---

final List<NewsItem> mockData = [
  NewsItem(
    id: '0',
    title: 'PAMBIANCO\nDIGIT',
    subtitle: 'The Future of Digital Luxury',
    type: PageType.cover,
    date: DateTime.now(),
  ),
  ),

  NewsItem(
    id: '2',
    title: 'L\'Evoluzione del Retail di Lusso',
    subtitle: 'Come il digitale sta riscrivendo le regole dell\'esperienza in-store.',
    category: 'RETAIL',
    author: 'Redazione Pambianco',
    content: 'Nel panorama attuale, il confine tra fisico e digitale svanisce. I brand più lungimiranti stanno integrando tecnologie as-a-service per creare percorsi d\'acquisto iper-personalizzati...\n\nIl futuro del lusso non risiede più solo nel prodotto, ma nell\'ecosistema di valori e servizi che lo circonda. Le nuove generazioni di consumatori cercano autenticità e fluidità.',
    imageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=2070&auto=format&fit=crop',
    type: PageType.article,
    layoutType: ArticleLayoutType.standard,
    date: DateTime.now(),
  ),
  NewsItem(
    id: '3',
    title: 'Rolex: Un Dominio Incontrastato',
    subtitle: 'Analisi di un record di fatturato.',
    category: 'WATCHES',
    author: 'Marco Rossi',
    content: 'Rolex si conferma leader assoluto, trainando la crescita dell\'intero comparto svizzero.',
    imageUrl: 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?q=80&w=2080&auto=format&fit=crop',
    quote: "La coerenza nel design e la precisione tecnica sono le chiavi del nostro successo centenario.",
    type: PageType.article,
    layoutType: ArticleLayoutType.quote,
    date: DateTime.now(),
  ),
  NewsItem(
    id: '4',
    title: 'Il Dilemma della Sostenibilità',
    subtitle: 'Sfide e opportunità per il lusso consapevole.',
    category: 'ENVIRONMENT',
    author: 'Giulia Bianchi',
    content: 'La trasparenza della supply chain è diventata l\'asset più critico per i marchi della moda. La sfida è trasformare un obbligo normativo in un vantaggio competitivo reale.',
    imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?q=80&w=2013&auto=format&fit=crop',
    type: PageType.article,
    layoutType: ArticleLayoutType.split,
    date: DateTime.now(),
  ),
  NewsItem(
    id: '5',
    title: 'Porsche: Design e Futuro',
    subtitle: 'Icona eterna, anima elettrica.',
    category: 'AUTOMOTIVE',
    author: 'Redazione Motori',
    content: 'La nuova era della mobilità non sacrifica il piacere della guida ma lo evolve.',
    imageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=2070&auto=format&fit=crop',
    type: PageType.article,
    layoutType: ArticleLayoutType.fullImage,
    date: DateTime.now(),
  ),

  NewsItem(

    id: '5',
    title: 'Porsche: Nuova Era Elettrica',
    subtitle: 'Partner Tecnico Ufficiale',
    type: PageType.adv,
    date: DateTime.now(),
    imageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=2070&auto=format&fit=crop',
  ),
];


// --- MAIN SCREEN ---

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;
  List<NewsItem> _dynamicData = List.from(mockData);
  bool _isLoadingModa = false;

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

  // Helper to get PDF URL from magazine content or meta if available
  String? _findPdfUrl(Map<String, dynamic> json) {
    // Check common places for PDF URL in custom fields
    if (json['meta'] != null) {
      if (json['meta']['pdf_url'] != null) return json['meta']['pdf_url'];
      if (json['meta']['_pdf_url'] != null) return json['meta']['_pdf_url'];
      if (json['meta']['magazine_pdf'] != null) return json['meta']['magazine_pdf'];
    }
    // FALLBACK: If we can't find it, we might need a specific field name from the USER
    return null;
  }

  Future<void> _fetchAllLiveContent() async {
    setState(() => _isLoadingModa = true);
    try {
      final service = WordPressService();
      final List<String> portals = ['MODA', 'DESIGN', 'BEAUTY', 'WINE&FOOD', 'HOTELLERIE', 'MAGAZINE'];
      
      for (String portal in portals) {
        final articles = await service.fetchArticlesForPortal(portal);
        if (articles.isNotEmpty) {
          setState(() {
            // Update the main cover image with the very first article we found (usually latest MODA or MAGAZINE)
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

            // Map our UI portal name to the ID in _dynamicData
            String internalId = 'index_${portal.toLowerCase().replaceAll('&', '').replaceAll(' ', '')}';
            
            int sectionIndex = _dynamicData.indexWhere((item) => item.id == internalId);
            if (sectionIndex != -1) {
              // Remove existing mock articles for this section
              String prefix = portal.split(' ')[0].toLowerCase() + '_';
              _dynamicData.removeWhere((item) => item.id.startsWith(prefix));
              
              // Insert real articles
              _dynamicData.insertAll(sectionIndex + 1, articles);
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching live content: $e');
    } finally {
      setState(() => _isLoadingModa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The Magazine Engine
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
          
          // Glass Dock Menu
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GlassDock(
                onCategoryTap: (category) {
                  int targetIndex = _dynamicData.indexWhere((e) => e.category == category);
                  if (targetIndex != -1) {
                    _pageController.animateToPage(
                      targetIndex, 
                      duration: const Duration(milliseconds: 600), 
                      curve: Curves.easeOutQuart,
                    );
                  } else if (category == 'INDICE') {
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
                  }
                },
              ),
            ),

          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// --- PAGE COMPONENTS ---

class MagazinePage extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  final PageController controller;

  const MagazinePage({
    super.key,
    required this.item,
    required this.parallaxRatio,
    required this.controller,
  });



  @override
  Widget build(BuildContext context) {
    // Basic 3D/Parallax Transform
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(parallaxRatio * 0.1),
      alignment: Alignment.center,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
        ),
        child: _buildLayout(context),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    switch (item.type) {
      case PageType.cover:
        return _CoverLayout(item: item);
      case PageType.toc:
        return const SizedBox.shrink(); // Removed TOC
      case PageType.article:
        return _ArticleDispatcher(item: item, parallaxRatio: parallaxRatio, controller: controller);


      case PageType.adv:
        return _AdvLayout(item: item);
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
          child: item.imageUrl != null 
            ? Image.network(item.imageUrl!, fit: BoxFit.cover)
            : Container(color: const Color(0xFF1A1A1A)),
        ),
        // Overlay Gradients for Readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(153), // 0.6 opacity
                Colors.transparent,
                Colors.black.withAlpha(204), // 0.8 opacity
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120), // Increased bottom padding to move text up
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'EDIZIONE DEL GIORNO',
                style: GoogleFonts.spaceMono(
                  fontSize: 14,
                  letterSpacing: 4,
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'PAMBIANCO\nDIGIT',
                style: GoogleFonts.bodoniModa(
                  fontSize: 84,
                  fontWeight: FontWeight.w900,
                  height: 0.85,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 30),
              Container(height: 1, width: 40, color: const Color(0xFFD4AF37)),
              const SizedBox(height: 20),
              Text(
                '${item.date.day} GENNAIO 2026',
                style: GoogleFonts.spaceMono(
                  fontSize: 14,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
}

class _IndexLayout extends StatelessWidget {
  final NewsItem item;
  const _IndexLayout({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            item.title,
            style: GoogleFonts.bodoniModa(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 2, width: 60, color: const Color(0xFFD4AF37)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              itemCount: mockData.where((e) => e.type == PageType.article).length,
              separatorBuilder: (_, __) => const SizedBox(height: 30),
              itemBuilder: (context, index) {
                final articles = mockData.where((e) => e.type == PageType.article).toList();
                final article = articles[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0${index + 1}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.category!,
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: GoogleFonts.bodoniModa(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
      case ArticleLayoutType.standard:
        return _ArticleStandardLayout(item: item, parallaxRatio: parallaxRatio);
      case ArticleLayoutType.split:
        return _ArticleStandardLayout(item: item, parallaxRatio: parallaxRatio); // Fallback to standard
      case ArticleLayoutType.quote:
        return _ArticleQuoteLayout(item: item, parallaxRatio: parallaxRatio);
      case ArticleLayoutType.fullImage:
        return _ArticleFullImageLayout(
          item: item, 
          parallaxRatio: parallaxRatio,
          onChildTap: (id) {
            int targetIndex = mockData.indexWhere((e) => e.id == id);
            if (targetIndex != -1) {
              controller.animateToPage(
                targetIndex,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutQuart,
              );
            }
          },
        );

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
      physics: const ClampingScrollPhysics(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -50,
                  right: -50,
                  top: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(parallaxRatio * 50, 0),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF0A0A0A),
                        const Color(0xFF0A0A0A).withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  item.category!,
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: GoogleFonts.bodoniModa(
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  item.subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  item.content!,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.white.withAlpha(217),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleSplitLayout extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  const _ArticleSplitLayout({required this.item, required this.parallaxRatio});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(parallaxRatio * 30, 0),
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(color: Colors.black26),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFF151515),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    item.category!,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    item.title,
                    style: GoogleFonts.bodoniModa(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.content!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'di ${item.author}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),

      ],
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
          Transform.translate(
            offset: Offset(0, parallaxRatio * -20),
            child: const Icon(Icons.format_quote, size: 60, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 20),
          Text(
            item.quote!,
            textAlign: TextAlign.center,
            style: GoogleFonts.bodoniModa(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),
          Container(height: 1, width: 40, color: const Color(0xFFD4AF37)),
          const SizedBox(height: 20),
          Text(
            item.author!.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            item.title,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleFullImageLayout extends StatelessWidget {
  final NewsItem item;
  final double parallaxRatio;
  final Function(String)? onChildTap;
  const _ArticleFullImageLayout({required this.item, required this.parallaxRatio, this.onChildTap});

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        Positioned.fill(
          child: Transform.scale(
            scale: 1.1 + (parallaxRatio.abs() * 0.1),
            child: Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(0),
                Colors.black.withAlpha(204),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category!.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        item.title,
                        style: GoogleFonts.bodoniModa(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        item.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.content!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                      if (item.childItems != null) ...[
                        const SizedBox(height: 40),
                        Container(
                          height: 1,
                          width: 40,
                          color: const Color(0xFFD4AF37).withAlpha(128),
                        ),
                        const SizedBox(height: 30),
                        ...item.childItems!.map((subItem) => Padding(
                          padding: const EdgeInsets.only(bottom: 25),
                          child: InkWell(
                            onTap: () {
                              if (onChildTap != null) onChildTap!(subItem.id);
                            },
                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subItem.title.toUpperCase(),
                                  style: GoogleFonts.bodoniModa(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  subItem.subtitle!,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 13,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),

              ],
            ),
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
        Image.network(
          item.imageUrl!,
          height: double.infinity,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black45,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PARTNER CONTENT',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.bodoniModa(
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  'DISCOVER MORE',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- GENERATIVE ART PAINTER ---

class GenerativeCoverPainter extends CustomPainter {
  final int seed;
  GenerativeCoverPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Background layers
    _drawRadialShade(canvas, size, random);
    
    // Abstract shapes
    for (int i = 0; i < 15; i++) {
      final color = _getLuxuryColor(random);
      paint.color = color.withAlpha((random.nextDouble() * 102).toInt()); // ~0.4 opacity
      paint.blendMode = BlendMode.screen;
      
      final type = random.nextInt(3);
      if (type == 0) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
          random.nextDouble() * 200 + 50,
          paint,
        );
      } else if (type == 1) {
        final path = Path();
        path.moveTo(random.nextDouble() * size.width, random.nextDouble() * size.height);
        path.quadraticBezierTo(
          random.nextDouble() * size.width, 
          random.nextDouble() * size.height,
          random.nextDouble() * size.width, 
          random.nextDouble() * size.height,
        );
        canvas.drawPath(path, paint..style = PaintingStyle.stroke..strokeWidth = random.nextDouble() * 10);
      } else {
        final rect = Rect.fromCenter(
          center: Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
          width: random.nextDouble() * 300,
          height: random.nextDouble() * 300,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawRadialShade(Canvas canvas, Size size, math.Random random) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1),
      radius: 1.5,
      colors: [
        const Color(0xFF1A1A1A),
        const Color(0xFF0A0A0A),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  Color _getLuxuryColor(math.Random random) {
    final colors = [
      const Color(0xFFD4AF37), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFF4A4A4A), // Charcoal
      const Color(0xFF2C3E50), // Navy
      const Color(0xFF8E44AD), // Royal Purple
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- GLASS DOCK ---

class GlassDock extends StatelessWidget {
  final Function(String) onCategoryTap;

  const GlassDock({super.key, required this.onCategoryTap});

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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DockIcon(icon: Icons.checkroom, label: 'MODA', onTap: () => onCategoryTap('MODA')),
                _DockIcon(icon: Icons.chair, label: 'DESIGN', onTap: () => onCategoryTap('DESIGN')),
                _DockIcon(icon: Icons.face, label: 'BEAUTY', onTap: () => onCategoryTap('BEAUTY')),
                _DockIcon(icon: Icons.restaurant, label: 'WINE', onTap: () => onCategoryTap('WINE&FOOD')),
                _DockIcon(icon: Icons.hotel, label: 'HOTEL', onTap: () => onCategoryTap('HOTELLERIE')),
                _DockIcon(icon: Icons.picture_as_pdf, label: 'MAGAZINE', onTap: () => onCategoryTap('MAGAZINE')),

              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showEdicolaGrid(BuildContext context) {
    final magazines = mockData.where((item) => item.id.startsWith('mag_')).toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EDICOLA',
                    style: GoogleFonts.bodoniModa(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                  itemCount: magazines.length,
                  itemBuilder: (context, index) {
                    final mag = magazines[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _openPdf(context, mag.pdfUrl!, mag.title);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                image: DecorationImage(
                                  image: NetworkImage(mag.imageUrl!),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(128),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            mag.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bodoniModa(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            mag.subtitle!,
                            style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
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

  void _openPdf(BuildContext context, String rawUrl, String title) {
    // Hide toolbar for web by appending #toolbar=0
    final String finalUrl = kIsWeb 
        ? 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(rawUrl)}#toolbar=0'
        : rawUrl;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: finalUrl,
          title: title,
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;
  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    // Register the PDF iframe for Web dynamically to honor #toolbar=0
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        'pdf-viewer-html-$pdfUrl',
        (int viewId) => html.IFrameElement()
          ..src = pdfUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          title,
          style: GoogleFonts.bodoniModa(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: kIsWeb 
        ? HtmlElementView(viewType: 'pdf-viewer-html-$pdfUrl')
        : SfPdfViewer.network(
            pdfUrl,
            canShowPaginationDialog: false,
            canShowScrollHead: false, // Cleaner UI
            canShowScrollStatus: false,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceMono(fontSize: 8, letterSpacing: 1, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
