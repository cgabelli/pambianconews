import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; // To access NewsItem
import 'package:flutter/foundation.dart';

class WordPressService {
  static const String mainBaseUrl = 'https://www.pambianconews.com/wp-json/wp/v2';
  
  // Portal Configurations
  static final Map<String, Map<String, dynamic>> portalConfigs = {
    'MODA': {'url': mainBaseUrl, 'category': 5},
    'DESIGN': {'url': 'https://design.pambianconews.com/wp-json/wp/v2', 'category': null},
    'BEAUTY': {'url': 'https://beauty.pambianconews.com/wp-json/wp/v2', 'category': null},
    'WINE&FOOD': {'url': 'https://wine.pambianconews.com/wp-json/wp/v2', 'category': null},
    'HOTELLERIE': {'url': 'https://hotellerie.pambianconews.com/wp-json/wp/v2', 'category': null},
    'MAGAZINE': {'url': 'https://magazine.pambianconews.com/wp-json/wp/v2', 'endpoint': 'r3d', 'category': null},
  };

  Future<List<NewsItem>> fetchArticlesForPortal(String portalName, {int perPage = 10}) async {
    final config = portalConfigs[portalName];
    if (config == null) return [];

    final baseUrl = config['url'] as String;
    final endpoint = (config['endpoint'] ?? 'posts') as String;
    final categoryId = config['category'] as int?;

    String url = '$baseUrl/$endpoint?per_page=$perPage&_embed';
    if (categoryId != null) {
      url += '&categories=$categoryId';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<NewsItem> items = [];
        
        for (var itemJson in data) {
          final item = NewsItem.fromWordPress(itemJson, portalName: portalName);
          
          if (portalName == 'MAGAZINE') {
            // v1.3 - Aggressive Fallback for Magazine Media
            try {
              String? foundPdf = item.pdfUrl;
              String? foundThumb = (item.imageUrl != null && !item.imageUrl!.contains('unsplash')) ? item.imageUrl : null;

              if (foundThumb == null || foundPdf == null) {
                final String safeTitle = item.title.replaceAll('_', ' ');
                final String searchUrl = '$baseUrl/media?search=${Uri.encodeComponent(safeTitle)}&per_page=10';
                final searchRes = await http.get(Uri.parse(searchUrl));
                if (searchRes.statusCode == 200) {
                  final List<dynamic> mediaItems = json.decode(searchRes.body);
                  for (var m in mediaItems) {
                    final String mMime = m['mime_type'].toString();
                    if (mMime == 'application/pdf' && foundPdf == null) foundPdf = m['source_url'];
                    if (mMime.contains('image') && foundThumb == null) foundThumb = m['source_url'];
                  }
                }
              }

              if (foundThumb == null) {
                // v1.6 - Multi-variant search (Beauty n6, Beauty_n6, etc.)
                final match = RegExp(r'n(\d+)').firstMatch(item.title);
                if (match != null) {
                  final String issueNum = match.group(1)!;
                  String category = 'magazine';
                  if (item.title.toLowerCase().contains('beauty')) category = 'beauty';
                  else if (item.title.toLowerCase().contains('design')) category = 'design';
                  else if (item.title.toLowerCase().contains('wine')) category = 'wine';
                  else if (item.title.toLowerCase().contains('hotellerie')) category = 'hotellerie';

                  final List<String> searchVariants = [
                    'cover $category n$issueNum',
                    '$category n$issueNum',
                    '${category}_n$issueNum',
                    item.title.split('_').first, // e.g. "PambiancoBeauty"
                  ];

                  for (final variant in searchVariants) {
                    final searchUrl = '${portalConfigs['MODA']!['url']}/media?search=${Uri.encodeComponent(variant)}&per_page=20';
                    final res = await http.get(Uri.parse(searchUrl));
                    if (res.statusCode == 200) {
                      final List<dynamic> mediaItems = json.decode(res.body);
                      for (var m in mediaItems) {
                        if (m['mime_type']?.startsWith('image/') == true) {
                          foundThumb = m['source_url'];
                          break;
                        }
                      }
                    }
                    if (foundThumb != null) break;
                  }
                }
              }

              if (foundThumb == null) {
                 // Final fallback: Title search on main site media
                 final String crossUrl = '${portalConfigs['MODA']!['url']}/media?search=${Uri.encodeComponent(item.title)}&per_page=20';
                 final crossRes = await http.get(Uri.parse(crossUrl));
                 if (crossRes.statusCode == 200) {
                   final List<dynamic> crossMedia = json.decode(crossRes.body);
                   for (var m in crossMedia) {
                     if (m['mime_type']?.startsWith('image/') == true) {
                       foundThumb = m['source_url'];
                       break;
                     }
                   }
                 }
              }

              if (foundThumb != null && kIsWeb) {
                 foundThumb = 'https://images.weserv.nl/?url=${Uri.encodeComponent(foundThumb)}&w=1000';
              }

              items.add(NewsItem(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                category: item.category,
                author: item.author,
                content: item.content,
                imageUrl: foundThumb ?? item.imageUrl,
                type: item.type,
                date: item.date,
                pdfUrl: foundPdf,
              ));
            } catch (e) {
              debugPrint('Error in Magazine Media Recovery: $e');
              items.add(item);
            }
          } else {
            items.add(item);
          }
        }
        return items;
      }
    } catch (e) {
      debugPrint('Error fetching WordPress articles for $portalName: $e');
    }
    return [];
  }
}
