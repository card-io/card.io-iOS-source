Expiry Segmentation
-------------------

## Overview

In the field of computer vision, "segmentation" refers to isolating relevant elements from an overall image, while "categorization" refers to examining a particular element and determining what it represents.

Here, we use "segmentation" to refer to locating good candidates for the expiry information in a credit card image. Specifically, we're going to identify groups of individual characters that we think might represent an expiration date. Then each of those individual characters will be "categorized" as a particular digit or a slash character, and the overall group evaluated as a possible expiration date.

False positives - identifying non-expiry pixels as a possible expiration date - are not only acceptable during segmentation, but expected. For example, some cards include a start date as well as an expiry date; our segmentation code will identify both of these.

False negatives - failing to identify the actual expiration date - are undesirable, but inevitable. That's why card.io looks at a live stream of images (30 frames per second) rather than just a single snapshot.


## Outline of the card-scanning process

#### 1. Identify the four card edges.

This is a surprisingly complicated task, described elsewhere [TBD].

**Note:** We obtain images from the phone's camera in the [YCbCr](http://en.wikipedia.org/wiki/YCbCr) format. The Y "plane" is the grayscale image; the other two planes contain all color information.

This is the only step that looks at all three planes. For all following steps, we use only the grayscale plane.

#### 2. Geometrically transform the image to produce a properly sized rectangle.

Described elsewhere [TBD].

#### 3. Locate the card number.

This is an even more complicated task! [TBD]

If unsuccessful, then proceed to next image from the video stream. Otherwise, continue.

#### 4. If we have not yet achieved confidence in the card number's value, then locate the individual card number digits and categorize them.

#### 5. If we have not yet achieved confidence in the expiry value, then in the part of the card below the card number, look for expiry candidates as described next.

Code for the following steps starts with `best_expiry_seg()` in `expiry_seg.cpp`.

#### 6. Submit the expiry candidates for categorization.


Look for expiry candidates
--------------------------

#### A. Assign each pixel a "verticalness" `score`

Each pixel's score is based on the degree to which it appears to be part of a near-vertical line segment.

The score indicates the difference in brightness on either side of the pixel, looking at not only the pixel's own row but also the rows immediately above and below. So this is a form of "edge detector" that is tuned to detect near-vertical line segments.

The strokes of the characters comprising an expiration date will score very highly in this step.

This score is calculated via the [Sobel operator](http://en.wikipedia.org/wiki/Sobel_operator) along the x-axis. (Actually, we are using a special case of Sobel known as the [Scharr operator](http://en.wikipedia.org/wiki/Sobel_operator#Alternative_operators).)

The score will be an integer in the range 0 to 32767.

*Original image:*

![Original image](./images/a-original.png)

*Sobel image:*

![Sobel image](./images/b-sobel.png)
  
#### B. Calculate the total score for each `row`.

A "row" is a rectangle one pixel in height, with width equal to 2/3 of the width of the card image.

Yes, 2/3.

Credit card logos often contain vertical elements that will receive high pixel scores. Fortunately for us, such logos are usually located at the right side of the card. For most cards we've seen so far, by ignoring the pixels within the right 1/3 of the card we avoid logos but still include expiration dates (and customer names, should we ever get to those).

*On the right third of this image, the brightness of each row indicates that row's total score.*

![Rows](./images/c-rows.png)


#### C. Calculate the total score for each `stripe`.

A "stripe" is a group of N contiguous rows, where N is the height of a standard expiry character.

There is a stripe for each y-coordinate of the card image below the card number (until you bump into the bottom of the card).

#### D. Determine the 3 non-overlapping stripes with the highest total scores.

Usually the 2 highest-scoring stripes will represent the expiry and the customer's name. But some cards have additional distractions.

*The position of the solid white rectangles indicate the ranking of the stripes.*

![Stripes](./images/d-stripes.png)

  
#### E. Within each of these 3 stripes, look for candidate groups of characters as described next.

All candidate groups will eventually be sent to the expiry categorization pipeline.


Look for candidate groups
-------------------------

#### i. Calculate the total score for each possible `character-rect` within the stripe.

A "character-rect" is a rectangle with the height and width of a standard expiry character.

There is a possible character-rect for each x-coordinate of the stripe (until you bump into the right margin).
  
#### ii. Determine the highest-scoring, non-overlapping character-rects.

*Although all calculations continue to be based on the Sobel image, we will use the original image in the following illustrations for easier visualization.*

*Character-rects*

![Character-rects 2](./images/e-2-char_rects.png)
![Character-rects 1](./images/e-1-char_rects.png)
![Character-rects 3](./images/e-3-char_rects.png)

#### iii. Examine this list of character-rects, and identify `groups`.

A "group" is a set of character-rects where the x-axis distance between each character-rect and the next is less than the width of a standard expiry character.

Each group includes as many character-rects as possible. E.g., if there are seven character-rects that meet the distance requirement, but their neighboring character-rects to the left and right are excessively distant, then all seven will be identified as belonging to a single group.

*Groups*

![Groups 2](./images/f-2-groups.png)
![Groups 1](./images/f-1-groups.png)
![Groups 3](./images/f-3-groups.png)

#### iv. For each group, tidy up the character-rects as described next.

Ignore groups of less than 5 character-rects, since the shortest valid expiry is `MM/YY`.


Tidy up each group
------------------

#### a. "Regrid" the group.

Now that we have identified a candidate group of character-rects, we reexamine the group to better identify the individual character-rects it contains.

We determine the best regular spacing of character-rects, and also the best margins within the group, which:

* minimizes the sum of pixel-scores *between* the character-rects, and
* maximizes the sum of pixel-scores *within* the character-rects.

I.e., we determine the spacing/margins which minimize the ratio of the former to the latter.

*Regridded groups*

![Regridded 2](./images/g-2-regrid.png)
![Regridded 1](./images/g-1-regrid.png)
![Regridded 3](./images/g-3-regrid.png)

#### b. "Optimize" the group.

Shift each character-rect a couple of pixels in all four directions, to determine the position that yields the highest total score for the character-rect.

Given a choice among equal-scoring shifts, we will choose the position with the highest scores for the top and left edges of the character-rect. I.e., we'll "normalize" each character image by shoving its significant pixels to the top-left of its character-rect.

*Optimized groups*

![Optimized 2](./images/h-2-optimize.png)
![Optimized 1](./images/h-1-optimize.png)
![Optimized 3](./images/h-3-optimize.png)

#### c. Look for a slash character, in a reasonable position.

Using a neural-net, deep-learning model, we evaluate each character-rect to see if it represents a slash character (`/`).

For the moment, the only expiration date pattern that we accept is `MM/YY`.

Therefore, the only groups accepted at this stage are those consisting of five character-rects, the middle character-rect being a slash character.

If a group contains more than 5 character-rects, then we break that group into 5-character-rect subgroups, and retain only those subgroups that have a central slash.

*Final result*

![Final image](./images/i-slash.png)
![Final image, magnified](./images/i-slash-magnified.png)
