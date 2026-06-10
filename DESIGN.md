---
name: Sejong Modern Crystal
colors:
  surface: '#f7f9fc'
  surface-dim: '#d8dadd'
  surface-bright: '#f7f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f7'
  surface-container: '#eceef1'
  surface-container-high: '#e6e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#191c1e'
  on-surface-variant: '#5c403f'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f4'
  outline: '#906f6e'
  outline-variant: '#e5bdbb'
  surface-tint: '#bf0229'
  primary: '#9e001f'
  on-primary: '#ffffff'
  primary-container: '#c8102e'
  on-primary-container: '#ffdad8'
  inverse-primary: '#ffb3b1'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#4b4d4d'
  on-tertiary: '#ffffff'
  tertiary-container: '#636565'
  on-tertiary-container: '#e2e3e3'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad8'
  primary-fixed-dim: '#ffb3b1'
  on-primary-fixed: '#410007'
  on-primary-fixed-variant: '#92001c'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c7'
  on-tertiary-fixed: '#1a1c1c'
  on-tertiary-fixed-variant: '#454747'
  background: '#f7f9fc'
  on-background: '#191c1e'
  surface-variant: '#e0e3e6'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Outfit
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Outfit
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Outfit
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Outfit
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  margin-mobile: 24px
  gutter-mobile: 16px
  stack-sm: 12px
  stack-md: 24px
  stack-lg: 48px
---

## Brand & Style

The design system embodies the prestige of a storied institution reimagined for the digital age. It centers on a **Soft Glassmorphism** aesthetic, blending the academic authority of Sejong University with a state-of-the-art, futuristic interface. The brand personality is professional, airy, and sophisticated.

The style leverages translucent layers, "frosted" surfaces, and high-fidelity depth to create a sense of lightness and clarity. By prioritizing generous whitespace and a clutter-free environment, the UI reduces cognitive load for students and faculty, reflecting an organized and innovative academic atmosphere. This approach moves away from traditional, heavy academic portals toward a sleek, mobile-first experience that feels like a premium lifestyle application.

## Colors

The palette is anchored by the university’s signature **Deep Crimson Red**, used purposefully for primary actions, branding moments, and progress indicators. **Charcoal Gray** provides high-contrast grounding for typography and secondary elements.

To achieve the "Soft Glass" effect, the system utilizes a foundation of **Pure White** and **HSL-tailored soft grays**. Backgrounds should not be flat; instead, use subtle, large-scale mesh gradients of very light grays and whites to provide the necessary visual texture for glass surfaces to "pop." Surface containers use semi-transparent white fills with high-saturation backdrop blurs to maintain legibility while evoking a sense of depth and modernity.

## Typography

**Outfit** is the sole typeface for this design system, chosen for its geometric precision and modern, approachable terminals. It bridges the gap between a tech-focused startup and an established academic institution.

- **Headlines:** Use Bold and Semi-Bold weights with slight negative letter-spacing to create a "tight," professional editorial look.
- **Body:** Use Regular weight for maximum readability. The line height is intentionally generous (1.5x+) to support the "clutter-free" brand promise.
- **Labels:** Use Medium or Semi-Bold weights in all-caps for utility elements to distinguish them from narrative text.

For mobile displays, headlines scale down to prevent awkward word breaks while maintaining their distinctive weight.

## Layout & Spacing

The design system employs a **Fluid Grid** model optimized for mobile devices. It utilizes a standard 4-column grid for mobile with a generous **24px side margin** to ensure content feels framed and premium. 

Spacing follows a strict **8px base unit** rhythm. However, to achieve the "generous whitespace" look, vertical stacks between major sections (e.g., between a glass card and a section header) should default to `stack-lg` (48px). This creates a rhythmic "breathing room" that prevents the information-dense university data from feeling overwhelming. Elements within cards should use the `gutter-mobile` (16px) for internal padding to maintain a compact but clear internal hierarchy.

## Elevation & Depth

Depth is not communicated through heavy dropshadows, but through **Tonal Layering and Backdrop Blurs**. 

1.  **Level 0 (Background):** Subtle mesh gradients in soft grays.
2.  **Level 1 (Surface):** Glassmorphic cards with a `backdrop-filter: blur(20px)`, a 70% white opacity fill, and a 1px solid border at 40% white opacity.
3.  **Level 2 (Active/Floating):** Elements like primary buttons or active modals use a slightly higher opacity or a very soft, diffused ambient shadow (Color: Charcoal Gray, Opacity: 4%, Blur: 30px) to indicate they are "closer" to the user.

Fine borders act as "light catchers" on the edges of cards, giving them a physical, crystalline quality without needing heavy shadows to define their bounds.

## Shapes

The shape language is defined by the **16px (1rem) corner radius**, providing a soft, modern feel that balances the sharp geometry of the typography. 

- **Cards and Containers:** Use the base 16px radius.
- **Buttons:** Use the `rounded-lg` (1rem/16px) or `rounded-xl` (1.5rem/24px) setting depending on the button size to maintain a consistent "pill-adjacent" look.
- **Input Fields:** Match the card radius (16px) to create a harmonious nested appearance when inputs are placed inside glass containers.
- **Progress Bars:** Use fully rounded (capsule) ends to emphasize fluid movement.

## Components

### Buttons
Primary buttons are solid **Deep Crimson Red** with white text. They should have a subtle inner glow on the top edge to simulate a "3D" tactile feel. Secondary buttons use a glass surface with a Charcoal Gray label.

### Glass Cards
The signature component. Every card must have a `backdrop-filter` and a fine 1px semi-transparent border. Avoid stacking cards directly on top of each other; use whitespace to separate them.

### Input Fields
Inputs are semi-transparent with a 1px Charcoal Gray border at 10% opacity. Upon focus, the border transitions to Deep Crimson Red.

### Progress Indicators
High-fidelity bars with a subtle gradient (Deep Crimson to a slightly lighter red). The background "track" of the progress bar should be a recessed, darker gray with a slight inner shadow to appear carved into the glass surface.

### Icons
Dual-tone minimalist icons. The primary stroke is Charcoal Gray, while a secondary decorative element or "accent" within the icon uses Deep Crimson Red at 20% opacity.

### Chips
Used for category tags (e.g., "Academic," "Event"). These should be small, pill-shaped glass elements with `label-sm` typography and a tiny crimson dot for "active" status.