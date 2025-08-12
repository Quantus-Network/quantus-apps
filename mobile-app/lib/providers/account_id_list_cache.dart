/// Cache to prevent infinite rebuilds when account ID hasn't changed
/// For everyone watching lists of accounts, use this to get
/// unique objects per list configuration.  
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
