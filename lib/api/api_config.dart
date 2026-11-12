class ApiConfig {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://ketring-45f82aef1ca0.herokuapp.com/api/v1');
}
