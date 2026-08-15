# Khair brand system

The approved Khair logo is the white geometric K on a vivid rose field. It is
symbol-only: render the product name as separate UI text when a wordmark is
needed.

## Canonical colour

- Primary rose: `#F43F75`
- Hover/dark rose: `#E63268`
- Soft rose: `#FFF1F5`
- Main text: `#171126`
- Background: `#FCFAFB`

## Official assets

All Flutter assets live in `frontend/khair_app/assets/branding/`.

- `khair_logo_source.png` — supplied, high-resolution approval source; never
  redraw it.
- `khair_logo_primary.png` — transparent-corner UI mark, based on the supplied
  source without its white canvas.
- `khair_logo_app_icon.png` — full rose app/PWA/iOS field with the white K in
  platform-safe padding.
- `khair_logo_maskable.png` — full rose maskable icon source.
- `khair_logo_notification.png` — white K on transparency, reserved for
  Android notification status icons and adaptive-icon foregrounds.
- `khair_logo_email.png` — full-field email logo.

The backend embeds the email asset in
`backend/pkg/brand/assets/khair_logo_email.png` and serves it from
`/brand/khair-logo.png`. Set `PUBLIC_BASE_URL` on Render so transactional
emails resolve that route to the production HTTPS origin. `KHAIR_BRAND_LOGO_URL`
is available only for a deliberate CDN override.

## Usage rules

- Flutter screens use `KhairBrandMark` or `KhairBrand` from
  `core/widgets/khair_brand.dart`; do not recreate the mark with Material
  icons or a letter K.
- The mark preserves its aspect ratio. UI marks need no coloured container,
  outline, or page-specific shadow.
- Keep the mark at least 24 logical pixels. At 16 px, use the generated
  favicon/app-icon raster rather than rendering a new approximation.
- Feature icons (calendar, people, mosque, map) retain their semantic purpose;
  none are substitutes for the Khair mark.
