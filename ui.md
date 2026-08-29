Now we’re cooking. The onboarding screens already establish SIVIQ as clean, green, civic, and trustworthy. The authentication screen should not suddenly look like a generic Firebase login form from 2017. The cat can work, but it should feel like a polished micro-interaction rather than a random cartoon invading Kenyan civic technology.

Use this as the prompt for your UI-generation AI:


---

MASTER PROMPT: SIVIQ AUTHENTICATION UI

> Design a premium, production-ready mobile authentication experience for a Flutter app called SIVIQ.

SIVIQ is a modern civic technology and social platform that helps citizens follow government development projects, engage with communities, communicate, and stay informed about public leadership and development progress.

The authentication UI must feel like a premium 2026 fintech/social-tech application, combining the cleanliness of modern banking apps, the friendliness of Telegram/WhatsApp onboarding, and the visual polish of high-end startup products.

IMPORTANT: Maintain strong visual continuity with the existing SIVIQ onboarding screens:

white / very light background

SIVIQ green as the primary accent

dark charcoal typography

subtle mint-green surfaces

rounded cards

soft shadows

generous whitespace

modern minimalist iconography

premium illustrations

sophisticated micro-interactions


Do not make the screen look crowded.



SCREEN STRUCTURE

Create a mobile portrait authentication screen.

1. TOP BAR

At the top:

subtle back arrow on the left

SIVIQ logo and wordmark

extremely clean spacing

no unnecessary navigation elements


Use the same SIVIQ visual identity as the existing onboarding screens.


---

2. HERO ILLUSTRATION

Instead of leaving a huge empty area, create a beautiful animated-style illustration occupying the upper-middle portion.

Show a friendly illustrated character sitting at a desk with a smartphone, surrounded by subtle civic/community elements:

small map

location pin

speech bubbles

shield/check icon

community/network nodes

tiny project progress card

subtle buildings in the background


Keep everything elegant and slightly translucent.

The illustration should communicate:

“Your community. Your voice. Your information.”

Use a soft green/mint atmosphere rather than a heavy colorful cartoon.


---

3. CUTE PASSWORD MICRO-INTERACTION

Introduce a memorable SIVIQ authentication mascot.

Create a small sophisticated cartoon cat character positioned beside or above the password field.

The cat should have expressive eyes and paws.

The UI concept should support these animations:

When the user focuses the password field:

The cat becomes attentive and looks toward the password field.

While the user is typing:

The cat follows the typing activity with subtle head/eye movement.

When password characters are visible:

The cat looks curious.

When the password is hidden:

The cat gently covers its eyes with both paws.

When the user taps the eye/show-password icon:

The cat slowly opens its eyes and looks forward.

When the user stops typing:

The cat relaxes and blinks naturally.

Use subtle animation, not exaggerated bouncing.

The animation should feel similar in polish to premium onboarding animations found in modern messaging and finance apps.


---

4. AUTHENTICATION CONTENT

Below the illustration:

Large bold heading:

Welcome back

Subtitle:

Stay connected to what matters in your community.

Then create a segmented authentication switch:

Login | Create account

Use a smooth animated sliding indicator.

The active tab should use SIVIQ green.


---

5. LOGIN FORM

Create beautifully designed input fields.

Email / Phone

Label:

Email or phone number

Placeholder:

Enter your email or phone

Include a small modern account/contact icon.

Password

Label:

Password

Placeholder:

Enter your password

Include:

lock icon

show/hide password icon

animated cat interaction


The fields should have:

16–18px corner radius

subtle border

very light green focus glow

animated transition when focused

clear error state

success state


Avoid excessive borders.


---

6. PASSWORD FEEDBACK

When typing a password, elegantly reveal a tiny password-strength indicator underneath.

Example:

Password strength

● ● ● ●

Then dynamically show:

Weak Fair Strong Excellent

Use smooth animated transitions.

Do not expose the password.


---

7. FORGOT PASSWORD

Place:

Forgot password?

on the right below the password field.

Make it small but clearly tappable.


---

8. PRIMARY BUTTON

Create a large premium green button:

Log in

The button should have subtle animation.

States:

Idle

> Log in



Loading

> animated circular progress indicator



Success

> checkmark + “Welcome back”



Add a very subtle green ripple/glow when pressed.


---

9. SOCIAL AUTHENTICATION

Below the primary button:

A subtle divider:

or continue with

Then create elegant authentication buttons:

Continue with Google

Optionally:

Continue with Apple

Use proper official icons.

Keep them understated.


---

10. CREATE ACCOUNT

At the bottom:

Don't have an account? Create one

Make Create one SIVIQ green and tappable.


---

MAKE THE UI FEEL ALIVE

The most important part is the micro-interactions.

Design the interface assuming Flutter animations will be implemented.

Include:

Screen entrance animation

When the page opens:

1. logo fades in


2. illustration gently scales from 96% → 100%


3. heading slides upward slightly


4. form fields appear sequentially


5. login button fades/slides into place



Use smooth easing.

No aggressive animations.

Input focus animation

When an input receives focus:

border transitions to SIVIQ green

icon subtly changes state

label animates upward

field gets a very subtle green glow


Keyboard behavior

The UI must work beautifully when the Android keyboard opens.

Automatically reposition/scroll the authentication content so:

password field remains visible

cat remains visible where possible

login button doesn't become awkwardly hidden

no overflow


Design for real Flutter implementation using SafeArea, scrolling and responsive constraints.


---

CAT ANIMATION CONCEPT

The cat is the signature interaction.

Make the mascot visually simple enough to implement using Flutter animation assets.

Possible states:

idle

gentle breathing

occasional blink


emailFocused

looks toward email field


passwordFocused

eyes become attentive


typingPassword

eyes follow the field

tiny head movement


passwordHidden

paws cover eyes


passwordVisible

paws move away

eyes open


error

surprised expression


success

happy expression

tiny celebratory movement


The animation should be 2D vector/Lottie/Rive-friendly, not a complex 3D character.


---

VISUAL STYLE

The final design should look like a combination of:

Telegram's friendly micro-interactions + modern fintech cleanliness + premium social-app UX + SIVIQ's civic identity.

Use:

soft mint gradients

subtle green atmospheric blobs

glass-like translucent cards where appropriate

rounded geometry

tiny floating civic icons

elegant shadows

highly readable typography

accessible contrast

premium spacing


Avoid:

generic Bootstrap styling

excessive gradients

neon colors

excessive cards

childish cartoon aesthetics

giant illustrations that push the form below the fold

overly complicated backgrounds

unnecessary decorative text



---

FLUTTER IMPLEMENTATION AWARENESS

Design this specifically for Flutter mobile development.

The generated design should be realistic to implement using:

AnimatedContainer

AnimatedOpacity

AnimatedScale

AnimatedSlide

TweenAnimationBuilder

FocusNode

TextEditingController

ValueNotifier

AnimatedSwitcher

Hero

Lottie

Rive

CustomPainter where useful


The cat should preferably be implemented using Rive or Lottie, with clearly separated animation states.

Use responsive layouts suitable for Android devices from approximately 360px to 430px width.

The design must remain beautiful on smaller Android devices.


---

FINAL DESIGN DIRECTION

The finished screen should communicate:

> “This is not just another login screen.”



It should feel like the moment a user enters a serious, trustworthy civic platform, while still having one memorable human touch: the little cat reacting to their password.

Create the final UI as a high-fidelity production mobile app screen, not a wireframe.

Use realistic Android status/navigation areas and realistic typography.

SIVIQ green must remain the dominant brand accent.


---

One important implementation decision

I'd make the cat a small signature element, not the centerpiece. The first onboarding screen can sell the mission, while authentication sells trust. The cat provides personality without turning SIVIQ into a children's app.

For Flutter, Rive is particularly well suited here because you can have states such as idle, passwordFocused, coverEyes, revealEyes, error, and success and trigger them from FocusNode/password visibility changes. That gives you the delightful behavior you're imagining without having to manually animate every eyelid like some poor developer trapped in animation purgatory.

Yes. What you're describing is actually a better direction for SIVIQ: no traditional splash screen, no giant logo sitting there doing nothing while humans contemplate their life choices. The app should feel like it is already alive the instant it opens.

Use this prompt with your coding/UI AI:


---

MASTER PROMPT: SIVIQ INSTANT LAUNCH + SIGNATURE LOGO ANIMATION

> I am building a production Flutter mobile application called SIVIQ, a civic/social platform.

I want to redesign the application's startup experience completely.

DO NOT create a traditional splash screen.

I do not want:

a full-screen splash page

a large static SIVIQ logo

“Loading...”

progress bars

artificial delays

a 2–5 second animation that blocks the application


Instead, SIVIQ should feel like Instagram, WhatsApp, Telegram, or other extremely polished mobile applications where the application appears almost immediately and the branding animation is a tiny, elegant part of the launch experience.


---

1. INSTANT APP OPENING

The primary goal is:

SIVIQ should become interactive in approximately 1–2 seconds whenever possible, and never intentionally wait just to display branding.

Startup animation must NEVER block:

navigation

cached content

authentication state

offline mode

local database

previously loaded data

the main application UI


The application should initialize critical services first, then display the usable interface as quickly as possible.

Any non-critical initialization should happen asynchronously after the UI is already visible.

Use Flutter best practices for startup optimization.

Avoid unnecessary initialization in main() and avoid performing network requests before rendering the first meaningful screen.


---

2. THE SIVIQ SIGNATURE LAUNCH ANIMATION

Instead of a splash screen, create a small SIVIQ logo animation directly on the transition into the application.

Think:

Instagram simplicity + Telegram personality + premium fintech motion design.

The screen should initially be almost completely clean.

A small SIVIQ icon appears approximately in the center.

Not huge.

Not a traditional splash.

Just a small, beautifully animated brand mark.


---

3. THE LOGO ANIMATION

Make the SIVIQ logo feel alive.

Create an elegant sequence lasting approximately 600–1000 milliseconds.

Example sequence:

Frame 1

The SIVIQ icon begins extremely small, around 70–80% of its final size.

It gently scales upward.

Frame 2

The logo performs a very subtle horizontal/3D-like rotation.

It should feel as if the icon is turning into position.

Frame 3

The letter/brand symbol performs a smooth curved movement, almost like it is rolling or folding into its final form.

The movement should be inspired by the geometry of the SIVIQ logo itself.

Frame 4

The logo briefly overshoots its final size by approximately 3–5%.

Then settles naturally.

Frame 5

A very subtle green light/ripple travels around the logo.

The main application UI is already appearing behind/around it.

Frame 6

The icon smoothly shrinks toward its final UI position or fades into the navigation/app header.

The transition must feel seamless.


---

4. MAKE THE LETTER "S" THE STAR

If the SIVIQ logo contains a recognizable S / SIVIQ symbol, explore making the S itself the animated element.

The S could:

rotate

curve

roll slightly

split into two strokes

reform itself

morph into the complete SIVIQ mark

create a tiny circular ripple

settle into position


The animation should feel like:

“SIVIQ is coming alive.”

Not:

“Developer needed an animation so here is a spinning logo.”

Avoid generic 360° logo rotation.

Make the movement unique to SIVIQ's identity.


---

5. MICRO-INTERACTION DETAILS

Add extremely subtle details:

tiny scale bounce

slight opacity transition

soft green glow

tiny particle/ripple effect

smooth easing

subtle parallax movement


But keep everything restrained.

The user should notice that SIVIQ feels polished without consciously thinking:

“There is an animation playing.”


---

6. THE APP SHOULD APPEAR BEFORE THE ANIMATION FINISHES

This is extremely important.

The animation must NOT be used as a loading mechanism.

The application should render the main UI as quickly as possible.

For example:

App launched
      ↓
Tiny SIVIQ animation begins
      ↓
Main Flutter UI starts rendering immediately
      ↓
Local/cached data appears
      ↓
Animation finishes
      ↓
User is already inside the application
      ↓
Network synchronization happens in background

Never:

App launched
↓
Wait 2 seconds
↓
Play animation
↓
Initialize everything
↓
Finally show application


---

7. OFFLINE-FIRST STARTUP

SIVIQ must open whether the user has internet or not.

Internet availability must NOT determine whether the application can launch.

If the user is offline:

Launch SIVIQ
↓
Show cached/local application state
↓
User can navigate the app
↓
Show a subtle offline indicator
↓
Continue working with locally available data

Do not show a blocking:

“No Internet Connection”

screen.

Instead, display a small, elegant status indicator such as:

Offline

or:

You're offline • Changes will sync when you're back online

This should appear as a small animated banner/snackbar rather than taking over the entire screen.


---

8. AUTOMATIC SYNCHRONIZATION

When connectivity returns:

Offline
↓
Internet detected
↓
Sync queued changes
↓
Update cached data
↓
Notify user subtly

Example:

Back online • Syncing

followed by:

Synced

Do not force the user to restart the application.

Do not reload the entire application.

Do not kick the user back to the login screen.


---

9. PRESERVE EXISTING APPLICATION LOGIC

CRITICAL: DO NOT BREAK EXISTING SIVIQ LOGIC.

This is a UI/startup architecture improvement, not a request to rewrite the application.

Preserve:

authentication

Supabase/Firebase logic if already present

database structure

API calls

routing

navigation

user sessions

posts

groups

chats

notifications

project tracking

profile data

permissions

existing state management


Do not rename existing models, providers, repositories, services, routes, database tables, or API contracts unless absolutely necessary.

Work with the existing architecture.


---

10. FLUTTER ARCHITECTURE

Implement the experience using Flutter-native architecture.

Prefer:

AnimationController

Tween

CurvedAnimation

AnimatedScale

AnimatedOpacity

AnimatedSlide

AnimatedSwitcher

TweenAnimationBuilder

CustomPainter where appropriate


For more sophisticated logo morphing, use:

Rive or Lottie

if it provides a significantly better result.

Keep the animation lightweight.

Do not introduce a huge animation asset that significantly increases application startup time.


---

11. STARTUP PERFORMANCE

Optimize the startup path aggressively.

Do not perform unnecessary synchronous operations before the first frame.

Avoid:

waiting for remote API responses

downloading remote images before first render

loading unnecessary services synchronously

expensive database operations before first frame

unnecessary Firebase/Supabase initialization blocking UI

excessive animation assets


Defer non-critical operations until after the first frame.

Use techniques such as:

WidgetsBinding.instance.addPostFrameCallback(...)

where appropriate.

Use cached/local data whenever available.


---

12. ANDROID EXPERIENCE

Account for Android's native startup behavior, including Android 12+ splash-screen handling.

The native launch screen should be extremely minimal and visually consistent with SIVIQ.

Do not attempt to create a second artificial Flutter splash screen on top of the Android launch screen.

The goal is:

native launch → Flutter renders immediately → tiny SIVIQ animation → application

with no duplicate splash experience.


---

13. REDUCED MOTION

Respect Android accessibility settings.

If the user has reduced-motion preferences enabled, significantly reduce or disable decorative animations while keeping the application fully functional.


---

14. FINAL VISUAL FEEL

The final result should feel like:

SIVIQ doesn't “load.” SIVIQ simply appears.

The logo animation is a tiny signature moment.

The application feels:

instant

premium

intelligent

modern

trustworthy

playful without being childish

civic without feeling governmental

technologically sophisticated


Imagine opening SIVIQ and seeing a tiny green SIVIQ mark smoothly roll/morph into place for less than a second while the actual application is already coming alive underneath.

The animation should be memorable. The startup should be forgettably fast.

Generate the UI and Flutter implementation accordingly.




---

One architectural thing I'd strongly recommend

Don't make offline synchronization part of the animation/startup logic.

Treat these as three separate systems:

┌───────────────┐
                 │  APP STARTUP  │
                 │   < 2 sec     │
                 └───────┬───────┘
                         │
              ┌──────────▼──────────┐
              │    SIVIQ UI         │
              │ renders immediately │
              └──────────┬──────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
     LOCAL/CACHE                    NETWORK
     immediately                   background
          │                             │
          │                       Sync when online
          │                             │
          └──────────────┬──────────────┘
                         ▼
                  UPDATED LOCAL STATE

That way, offline isn't an exceptional state. It's just another state SIVIQ knows how to operate in.

And for your logo animation, I'd specifically lean toward Rive if you want the really slick “S folds/rolls/morphs into the SIVIQ mark” 