// Test-only fixtures shaped like WordPress REST API responses
// (`/wp-json/wp/v2/posts?_embed`). Never used by the app itself.

Map<String, dynamic> wpPost({
  int id = 101,
  String slug = 'tems-biography',
  String title = 'Tems&#8217; Biography: From Lagos to the World',
  String excerpt = '<p>The singer&#8217;s journey so far [&hellip;]</p>',
  String? content =
      '<p>Temilade Openiyi, known as <strong>Tems</strong>, was born in Lagos.</p>'
      '<h2>Early life</h2><p>She grew up between <a href="https://allbiohub.com/category/biography/">Nigeria</a> and the UK.</p>',
  bool withImage = true,
  bool authorError = false,
  List<int> categories = const [137, 1],
  bool sticky = false,
}) => {
  'id': id,
  'date': '2026-09-28T07:29:28',
  'date_gmt': '2026-09-28T06:29:28',
  'modified': '2026-09-28T08:00:00',
  'modified_gmt': '2026-09-28T07:00:00',
  'slug': slug,
  'link': 'https://allbiohub.com/$slug/',
  'title': {'rendered': title},
  'excerpt': {'rendered': excerpt, 'protected': false},
  if (content != null) 'content': {'rendered': content, 'protected': false},
  'author': 3,
  'featured_media': withImage ? 12882 : 0,
  'categories': categories,
  'tags': [55],
  'sticky': sticky,
  '_links': {},
  '_embedded': {
    'author': [
      if (authorError)
        {
          'code': 'rest_user_invalid_id',
          'message': 'Invalid user ID.',
          'data': {'status': 404},
        }
      else
        {
          'id': 3,
          'name': 'Ada Obi',
          'slug': 'ada',
          'avatar_urls': {
            '24': 'https://secure.gravatar.com/a?s=24',
            '96': 'https://secure.gravatar.com/a?s=96',
          },
        },
    ],
    if (withImage)
      'wp:featuredmedia': [
        {
          'id': 12882,
          'alt_text': 'Tems performing',
          'caption': {'rendered': '<p>Tems on stage</p>'},
          'source_url':
              'https://allbiohub.com/wp-content/uploads/2026/09/tems.jpg',
          'media_details': {
            'width': 1600,
            'height': 1000,
            'sizes': {
              'thumbnail': {
                'source_url': 'https://allbiohub.com/wp-content/uploads/2026/09/tems-150x150.jpg',
                'width': 150,
                'height': 150,
              },
              'medium': {
                'source_url': 'https://allbiohub.com/wp-content/uploads/2026/09/tems-300x188.jpg',
                'width': 300,
                'height': 188,
              },
              'large': {
                'source_url': 'https://allbiohub.com/wp-content/uploads/2026/09/tems-1024x640.jpg',
                'width': 1024,
                'height': 640,
              },
            },
          },
        },
      ],
    'wp:term': [
      [
        {
          'id': 1,
          'name': 'BIOGRAPHY',
          'slug': 'biography',
          'taxonomy': 'category',
        },
        {
          'id': 137,
          'name': 'CELEBRITY NEWS',
          'slug': 'celebrity-news',
          'taxonomy': 'category',
        },
      ],
      [
        {
          'id': 55,
          'name': 'Afrobeats',
          'slug': 'afrobeats',
          'taxonomy': 'post_tag',
        },
      ],
    ],
  },
};

/// The live site's categories (October 2026).
List<Map<String, dynamic>> wpCategories() => [
  {
    'id': 124,
    'name': 'AROUND THE WEB',
    'slug': 'around-the-web',
    'count': 207,
    'description': '',
    'parent': 0,
  },
  {
    'id': 1,
    'name': 'BIOGRAPHY',
    'slug': 'biography',
    'count': 379,
    'description': '',
    'parent': 0,
  },
  {
    'id': 137,
    'name': 'CELEBRITY NEWS',
    'slug': 'celebrity-news',
    'count': 346,
    'description': '',
    'parent': 0,
  },
  {
    'id': 777,
    'name': 'EDITORIAL SUBMISSION',
    'slug': 'editorial-submission',
    'count': 1,
    'description': '',
    'parent': 0,
  },
  {
    'id': 216,
    'name': 'MONEY &amp; CAREER',
    'slug': 'money-career',
    'count': 13,
    'description': '',
    'parent': 0,
  },
  {
    'id': 206,
    'name': 'REVIEWS',
    'slug': 'reviews',
    'count': 14,
    'description': '',
    'parent': 0,
  },
  {
    'id': 639,
    'name': 'SPONSORED',
    'slug': 'sponsored',
    'count': 0,
    'description': '',
    'parent': 0,
  },
  {
    'id': 231,
    'name': 'STARTUP FOUNDERS &amp; INNOVATOR',
    'slug': 'startup-founders-innovator',
    'count': 27,
    'description': '',
    'parent': 0,
  },
  {
    'id': 611,
    'name': 'WOMEN IN TECH',
    'slug': 'women-in-tech',
    'count': 4,
    'description': '',
    'parent': 0,
  },
];

Map<String, dynamic> startupJson({
  int id = 7,
  String slug = 'vast',
  String name = 'Vast',
  bool verified = false,
  bool claimed = false,
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'link': 'https://allbiohub.com/startups/$slug/',
  'tagline': 'Haven-1, a commercial space station',
  'industry': 'Habitats',
  'country': 'United States',
  'city': '',
  'founded': 2021,
  'stage': 'Series A',
  'funding': 'Founder funding',
  'status': 'Active',
  'website': 'https://vastspace.com',
  'verified': verified,
  'claimed': claimed,
  'featured': false,
  'founders': [
    {'name': 'Jed McCaleb', 'role': 'Founder'},
  ],
  'social': {'linkedin': 'https://linkedin.com/company/vast', 'x': ''},
  'created_at': '2026-09-25T10:00:00Z',
};
