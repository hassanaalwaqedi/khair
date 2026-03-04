package i18n

import (
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	// ContextLocaleKey is where resolved locale is stored in request context.
	ContextLocaleKey = "locale"

	LocaleEnglish = "en"
	LocaleArabic  = "ar"
)

type messageSet struct {
	En string
	Ar string
}

var dynamicWaitSecondsPattern = regexp.MustCompile(`^please wait (\d+) seconds before requesting a new code$`)

var messageCatalog = map[string]messageSet{
	"invalid_request":                       {En: "Invalid request", Ar: "طلب غير صالح"},
	"invalid_email_or_password":             {En: "invalid email or password", Ar: "البريد الإلكتروني أو كلمة المرور غير صحيحة"},
	"registration_failed_try_again":         {En: "registration failed, please try again", Ar: "فشل التسجيل، يرجى المحاولة مرة أخرى"},
	"failed_to_process_registration":        {En: "failed to process registration", Ar: "تعذر إكمال عملية التسجيل"},
	"failed_to_create_account":              {En: "failed to create account", Ar: "تعذر إنشاء الحساب"},
	"failed_to_create_organizer_profile":    {En: "failed to create organizer profile", Ar: "تعذر إنشاء ملف المنظم"},
	"verification_code_sent":                {En: "Verification code sent to your email", Ar: "تم إرسال رمز التحقق إلى بريدك الإلكتروني"},
	"email_not_verified_check_inbox":        {En: "email not verified, please check your inbox for the verification code", Ar: "لم يتم التحقق من البريد الإلكتروني، يرجى مراجعة صندوق الوارد للحصول على رمز التحقق"},
	"failed_to_generate_token":              {En: "failed to generate token", Ar: "تعذر إنشاء رمز الدخول"},
	"invalid_verification_request":          {En: "invalid verification request", Ar: "طلب تحقق غير صالح"},
	"too_many_failed_attempts":              {En: "too many failed attempts, please request a new verification code", Ar: "عدد محاولات فاشلة كبير، يرجى طلب رمز تحقق جديد"},
	"verification_code_expired":             {En: "verification code has expired, please request a new one", Ar: "انتهت صلاحية رمز التحقق، يرجى طلب رمز جديد"},
	"invalid_verification_code":             {En: "invalid verification code", Ar: "رمز التحقق غير صحيح"},
	"failed_to_verify_email":                {En: "failed to verify email", Ar: "تعذر التحقق من البريد الإلكتروني"},
	"email_verified_successfully":           {En: "Email verified successfully", Ar: "تم التحقق من البريد الإلكتروني بنجاح"},
	"if_email_registered_code_sent":         {En: "If that email is registered, a new verification code has been sent", Ar: "إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز تحقق جديد"},
	"email_already_verified":                {En: "Email is already verified", Ar: "تم التحقق من البريد الإلكتروني مسبقاً"},
	"failed_to_generate_verification_code":  {En: "failed to generate verification code", Ar: "تعذر إنشاء رمز التحقق"},
	"failed_to_update_verification_code":    {En: "failed to update verification code", Ar: "تعذر تحديث رمز التحقق"},
	"failed_to_send_verification_email":     {En: "failed to send verification email", Ar: "تعذر إرسال رسالة التحقق"},
	"authorization_header_required":         {En: "Authorization header is required", Ar: "ترويسة التفويض مطلوبة"},
	"invalid_authorization_header_format":   {En: "Invalid authorization header format", Ar: "صيغة ترويسة التفويض غير صحيحة"},
	"invalid_token":                         {En: "Invalid token", Ar: "رمز الدخول غير صالح"},
	"invalid_user_id_in_token":              {En: "Invalid user ID in token", Ar: "معرف المستخدم داخل رمز الدخول غير صالح"},
	"invalid_token_claims":                  {En: "Invalid token claims", Ar: "بيانات رمز الدخول غير صالحة"},
	"admin_access_required":                 {En: "Admin access required", Ar: "يتطلب صلاحية المشرف"},
	"organizer_access_required":             {En: "Organizer access required", Ar: "يتطلب صلاحية المنظم"},
	"authentication_required":               {En: "Authentication required", Ar: "المصادقة مطلوبة"},
	"invalid_user_id":                       {En: "Invalid user ID", Ar: "معرف المستخدم غير صالح"},
	"invalid_user_id_type":                  {En: "Invalid user ID type", Ar: "نوع معرف المستخدم غير صالح"},
	"organization_id_required":              {En: "Organization ID is required", Ar: "معرف المنظمة مطلوب"},
	"invalid_organization_id":               {En: "Invalid organization ID", Ar: "معرف المنظمة غير صالح"},
	"not_member_of_organization":            {En: "You are not a member of this organization", Ar: "أنت لست عضواً في هذه المنظمة"},
	"failed_check_organization_membership":  {En: "Failed to check organization membership", Ar: "تعذر التحقق من عضوية المنظمة"},
	"insufficient_organization_permissions": {En: "Insufficient organization permissions", Ar: "صلاحيات المنظمة غير كافية"},
	"invalid_latitude":                      {En: "Invalid latitude", Ar: "خط العرض غير صالح"},
	"invalid_longitude":                     {En: "Invalid longitude", Ar: "خط الطول غير صالح"},
	"failed_resolve_location":               {En: "Failed to resolve location", Ar: "تعذر تحديد الموقع"},
	"failed_resolve_location_ip":            {En: "Failed to resolve location from IP", Ar: "تعذر تحديد الموقع من عنوان IP"},
	"failed_load_filter_options":            {En: "Failed to load filter options", Ar: "تعذر تحميل خيارات التصفية"},
	"invalid_interaction_payload":           {En: "Invalid interaction payload", Ar: "بيانات التفاعل غير صالحة"},
	"session_hash_required":                 {En: "session_hash is required", Ar: "حقل session_hash مطلوب"},
	"invalid_event_type":                    {En: "invalid event_type", Ar: "نوع الحدث غير صالح"},
	"failed_track_interaction":              {En: "Failed to track interaction", Ar: "تعذر تسجيل التفاعل"},
	"invalid_lat_lng_values":                {En: "invalid latitude/longitude values", Ar: "قيم خط العرض/خط الطول غير صالحة"},
	"bounding_box_exceeds_limits":           {En: "bounding box exceeds safe map query limits", Ar: "حدود الخريطة المطلوبة تتجاوز النطاق الآمن"},
	"auth_required_personalized":            {En: "authentication required for personalized recommendations", Ar: "المصادقة مطلوبة للتوصيات المخصصة"},
	"event_not_found":                       {En: "Event not found", Ar: "الفعالية غير موجودة"},
	"endpoint_not_found":                    {En: "Endpoint not found", Ar: "المسار غير موجود"},
	"invalid_quote_location":                {En: "Invalid quote location", Ar: "موضع الاقتباس غير صالح"},
	"quote_not_found":                       {En: "No active quote available", Ar: "لا يوجد اقتباس نشط متاح"},
	"failed_fetch_quote":                    {En: "Failed to load spiritual quote", Ar: "تعذر تحميل الاقتباس الروحي"},
}

var englishMessageIndex map[string]string

func init() {
	englishMessageIndex = make(map[string]string, len(messageCatalog))
	for key, msg := range messageCatalog {
		englishMessageIndex[msg.En] = key
	}
}

// DetectLocale resolves a supported locale from Accept-Language.
func DetectLocale(acceptLanguage string) string {
	if acceptLanguage == "" {
		return LocaleEnglish
	}

	parts := strings.Split(acceptLanguage, ",")
	for _, part := range parts {
		token := strings.TrimSpace(strings.ToLower(part))
		if token == "" {
			continue
		}
		lang := token
		if semi := strings.Index(lang, ";"); semi >= 0 {
			lang = strings.TrimSpace(lang[:semi])
		}
		if dash := strings.Index(lang, "-"); dash >= 0 {
			lang = lang[:dash]
		}
		switch lang {
		case LocaleArabic:
			return LocaleArabic
		case LocaleEnglish:
			return LocaleEnglish
		}
	}

	return LocaleEnglish
}

func localeFromContext(c *gin.Context) string {
	if c == nil {
		return LocaleEnglish
	}
	if raw, ok := c.Get(ContextLocaleKey); ok {
		if locale, ok := raw.(string); ok && locale != "" {
			return locale
		}
	}
	return LocaleEnglish
}

func resolveCatalogKey(keyOrMessage string) string {
	if _, ok := messageCatalog[keyOrMessage]; ok {
		return keyOrMessage
	}
	if key, ok := englishMessageIndex[keyOrMessage]; ok {
		return key
	}
	return ""
}

// Translate returns a localized string for the provided key or known English message.
func Translate(locale, keyOrMessage string) string {
	if keyOrMessage == "" {
		return keyOrMessage
	}

	if strings.HasPrefix(keyOrMessage, "Invalid request: ") {
		base := Translate(locale, "invalid_request")
		details := strings.TrimSpace(strings.TrimPrefix(keyOrMessage, "Invalid request: "))
		if details == "" {
			return base
		}
		return base + ": " + details
	}

	if matches := dynamicWaitSecondsPattern.FindStringSubmatch(strings.ToLower(strings.TrimSpace(keyOrMessage))); len(matches) == 2 {
		if locale == LocaleArabic {
			return "يرجى الانتظار " + matches[1] + " ثانية قبل طلب رمز جديد"
		}
		return keyOrMessage
	}

	key := resolveCatalogKey(keyOrMessage)
	if key == "" {
		return keyOrMessage
	}

	msg := messageCatalog[key]
	if locale == LocaleArabic && msg.Ar != "" {
		return msg.Ar
	}
	if msg.En != "" {
		return msg.En
	}
	return keyOrMessage
}

// TranslateForContext localizes key/message based on locale resolved in request context.
func TranslateForContext(c *gin.Context, keyOrMessage string) string {
	return Translate(localeFromContext(c), keyOrMessage)
}
