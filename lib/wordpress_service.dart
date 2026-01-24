import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; // To access NewsItem

class WordPressService {
  static const String mainBaseUrl = 'https://www.pambianconews.com/wp-json/wp/v2';
  
  // Portal Configurations
  static final Map<String, Map<String, dynamic>> portalConfigs = {
    'MODA': {'url': mainBaseUrl, 'category': 5},
    'DESIGN': {'url': 'https://design.pambianconews.com/wp-json/wp/v2', 'category': null},
    'BEAUTY': {'url': 'https://beauty.pambianconews.com/wp-json/wp/v2', 'category': null},
    'WINE&FOOD': {'url': 'https://wine.pambianconews.com/wp-json/wp/v2', 'category': null},
    'HOTELLERIE': {'url': 'https://hotellerie.pambianconews.com/wp-json/wp/v2', 'category': null},
    'MAGAZINE': {'url': 'https://magazine.pambianconews.com/wp-json/wp/v2', 'category': null},
  };

  Future<List<NewsItem>> fetchArticlesForPortal(String portalName, {int perPage = 10}) async {
    final config = portalConfigs[portalName];
    if (config == null) return [];

    final String baseUrl = config['url'];
    final int? categoryId = config['category'];
    
    final queryParams = {
      'per_page': perPage.toString(),
      '_embed': '',
    };
    if (categoryId != null) {
      queryParams['categories'] = categoryId.toString();
    }

    final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) {
          final item = NewsItem.fromWordPress(json);
          // Ensure the category field matches the portal name for consistency
          return NewsItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            category: portalName,
            author: item.author,
            content: item.content,
            imageUrl: item.imageUrl,
            quote: item.quote,
            type: item.type,
            layoutType: item.layoutType,
            date: item.date,
            childItems: item.childItems,
            pdfUrl: item.pdfUrl,
          );
        }).toList();
      } else {
        throw Exception('Failed to load articles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching WordPress articles for $portalName: $e');
      return [];
    }
  }
}
