const defaultRepositories = [
  SvnRepository('ET1288_AP', 'https://svn1.embestor.local/svn/ET1288_AP'),
  SvnRepository('ET1289_AP', 'https://svn1.embestor.local/svn/ET1289_AP'),
  SvnRepository('ET1290_AP', 'https://svn1.embestor.local/svn/ET1290_AP'),
];

class SvnRepository {
  const SvnRepository(this.name, this.url, {this.subtitle = ''});

  factory SvnRepository.fromJson(Map<String, dynamic> json) {
    return SvnRepository(
      json['title']?.toString().trim() ?? '',
      json['svn_base_url']?.toString().trim() ?? '',
      subtitle: json['sub_title']?.toString().trim() ?? '',
    );
  }

  final String name;
  final String url;
  final String subtitle;

  Map<String, dynamic> toJson() => {
        'title': name,
        'sub_title': subtitle,
        'svn_base_url': url,
      };
}

SvnRepository? matchRepository(
  List<SvnRepository> repositories,
  SvnRepository? selected,
) {
  if (selected == null) {
    return null;
  }
  for (final repository in repositories) {
    if (repository.name == selected.name) {
      return repository;
    }
  }
  return null;
}
