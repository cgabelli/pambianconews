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
            String? foundPdf = item.pdfUrl;
            String? foundThumb = (item.imageUrl != null && !item.imageUrl!.contains('unsplash')) ? item.imageUrl : null;

            // Try to fetch attachments if data is missing
            try {
              final attachmentsUrl = '$baseUrl/media?parent=${item.id}';
              final mediaRes = await http.get(Uri.parse(attachmentsUrl));
              if (mediaRes.statusCode == 200) {
                final List<dynamic> mediaData = json.decode(mediaRes.body);
                for (var media in mediaData) {
                  if (media['mime_type'] == 'application/pdf' && foundPdf == null) {
                    foundPdf = media['source_url'];
                  } else if (media['mime_type'].toString().contains('image') && foundThumb == null) {
                    foundThumb = media['source_url'];
                  }
                }
              }

              // FALLBACK: Search media by title if still nothing
              if (foundThumb == null || foundPdf == null) {
                final searchUrl = '$baseUrl/media?search=${Uri.encodeComponent(item.title)}';
                final searchRes = await http.get(Uri.parse(searchUrl));
                if (searchRes.statusCode == 200) {
                  final List<dynamic> searchData = json.decode(searchRes.body);
                  for (var media in searchData) {
                    if (media['mime_type'] == 'application/pdf' && foundPdf == null) {
                      foundPdf = media['source_url'];
                    } else if (media['mime_type'].toString().contains('image') && foundThumb == null) {
                      foundThumb = media['source_url'];
                    }
                  }
                }
              }
            } catch (e) {
              print('Error fetching attachments for magazine ${item.id}: $e');
            }

            // Reconstruction with CORS proxy if needed
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
          } else {
            items.add(item);
          }
        }
        return items;
      }
    } catch (e) {
      print('Error fetching WordPress articles for $portalName: $e');
    }
    return [];
  }
}
