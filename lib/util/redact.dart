/// [text] with the user name and password taken out of every URL in it
/// (`smb2://user:password@host/...` becomes `smb2://host/...`, nested URLs
/// included), so a log line or a label never shows credentials.
String withoutCredentials(String text) => text.replaceAll(_userInfo, '://');

final _userInfo = RegExp(r'://[^/@\s]*@');
