# Mail Dialog Mock Design

## Goal

Replace the legacy one-row mail popup with a scalable portrait inbox mock in the fixed Meadow Sky + Cut-Paper Playground direction.

## Composition

- Use a full `1080x1920` iPhone canvas with the game world softly dimmed behind a centered warm-cream paper modal.
- Keep the title `MAIL` and a coral circular close button in the header.
- Show three vertically stacked message cards. Each card has an unread/read marker, a simple mail or gift icon, a short title and preview, one or two reward pills, and a large action-green `CLAIM` button.
- Use three distinct reward examples: 100 coins; 3 water and 1 acorn; one small gift chest.
- Place a single full-width `CLAIM ALL` button at the bottom of the modal, separated from the individual cards.
- Keep all text and tap targets readable at phone size; the inbox must remain usable when more messages are added by scrolling.

## Visual Rules

- Follow `docs/design/art-style-guide.md` without changing its palette or material treatment.
- Warm cream is the dominant dialog surface, ink/slate handles text and structure, green is reserved for claims, coral for the close/unread accent, and gold for rewards.
- Use shallow down-right tinted shadows, fine warm cut edges, restrained paper fiber, and broad rounded silhouettes.
- Avoid glossy plastic, clay, painterly gradients, heavy black outlines, white sticker borders, decorative clutter, and large empty areas.

## Deliverables

- Native generated source image.
- `1080x1920` review copy.
- Exact production prompt stored beside the image.
- Dialog concept index updated with the new mock.
