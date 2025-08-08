/// Cache to prevent infinite rebuilds when account ID hasn't changed
final _searchParameterCache = <String, List<String>>{};

class AccountIdListCache {
  static List<String> get(List<String> accountIds) {
    final key = accountIds.join(',');
    if (_searchParameterCache.containsKey(key)) {
      return _searchParameterCache[key]!;
    }
    _searchParameterCache[key] = accountIds;
    return accountIds;
  }
}
