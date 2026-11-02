import "package:flutter_test/flutter_test.dart";
import "package:itilms_mobile/auth/models.dart";

void main() {
  test("extra duties count as roles", () {
    final u = AppUser.fromJson({"id": 1, "role": "STUDENT", "extraRoles": ["FINANCE"]});
    expect(u.hasRole(["FINANCE"]), isTrue);
    expect(u.hasRole(["ADMIN"]), isFalse);
  });
}
