# Drop item art here

The game auto-loads `assets/items/<family>_<tier>.png` and shows it on the tile;
if a file is missing it falls back to a colored placeholder with the tier number.

Expected files (512×512, transparent PNG — see ../../ICON_PROMPTS.md for prompts):

```
clothes_1.png  clothes_2.png  clothes_3.png  clothes_4.png  clothes_5.png
books_1.png    books_2.png    books_3.png    books_4.png    books_5.png
toys_1.png     toys_2.png     toys_3.png     toys_4.png     toys_5.png
```

After adding files, open the project in the Godot editor once so it imports them.
