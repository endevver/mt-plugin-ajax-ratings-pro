# Ajax Ratings Pro

http://mt-hacks.com/ajaxrating.html

Refer to the above URL for documentation on this plugin. The following
documents additions made since version 1.261.

Compatible with Movable Type 4.x, 5.1+, and 6.x.

# Upgrading

Version 1.3+ is converted to a `config.yaml` style plugin. Be sure to remove
the old `AjaxRating.pl` file when upgrading.

The upgrade process itself may not go smoothly with this change. You should
expect to see an upgrade notice from MT twice: once to install the
`config.yaml` style plugin, and a second time to migrate and update data.

Version 1.3 also changes its table names, shortening them for compatibility
with Oracle. This change won't require any modification to your templates. The
change does require you to work with the database: the old table
`mt_ajaxrating_votesummary` will need a new column created:
`ajaxrating_votesummary_vote_dist` as type `text`. This must be done before
the new plugin is installed.

Plugin data is stored differently with the `config.yaml` style, so you will
need to re-set Ajax Rating Plugin Settings, at both the System and Blog level.

# Configuration

In System Overview > Plugins > Ajax Rating Pro > Settings, you'll find an
option to Enable IP Checking. This checkbox provides an easy way to restrict
votes by IP address. Disable during development for easy testing.

# Tag Reference

The following template tags are available in Ajax Rating for both static and dynamic (php)
publishing.

## AjaxStarRater

This tag will output a star rater like the one shown above. To rate entries, it must be used in
an Entry context (i.e. between `<MTEntries>` and `</MTEntries>` tags or in the Individual
Archive Template. A good spot is just after the `<MTEntryBody>` tag.

**Supported arguments**

   * **`type`**

       * Required when rating a blog but generally recommended otherwise. With Ajax Rating Pro,
         you can also specify the following types:

           * `entry` (*default*)
           * `comment`
           * `category`
           * `author`
           * `tag`,
           * `trackback` (*alias:* `ping`)
           * ...or anything else (see "rate anything" above).

   * **`max_points`**

       * Required for all types except entries and comments. This argument specifies the number
         of stars that will be displayed.

   * **`id`**

       * (*Advanced*), This argument enables you specify a specific object ID number that you
         want to rate. If you use the tag in the correct context, you don't need to include the
         `id` argument. But if you want to place a rater outside of the relevant context, or if
         you want to rate a non-MT object (see "rate anything" above), then you must specify
         the id of the object. Normally, you don't want to use this, so forget I mentioned it.
         ;)

**Examples**

This creates a star rater for the entry in context:

    <mt:AjaxStarRater type="entry">

This creates a star rater for the blog in context:
    
    <mt:AjaxStarRater type="blog">

This creates a 5-star rater for the blog in context:

    <mt:AjaxStarRater type="blog" max_points="5">

In an author or commenter is in context (e.g. the author on an author profile page, the comment
author in a comment context, the entry/page author in an entry context, etc), this creates a
star rater for your mom (or, rather, the author in context) with 10-stars (because she deserves
nothing less):

    <mt:If tag="CommenterID">   <mt:CommenterID setvar="user_id">
    <mt:ElseIf tag="AuthorID">  <mt:AuthorID setvar="user_id">
    <mt:Else>                   <mt:Var name="user_id" value="">
    </mt:If>
    <mt:If var="user_id">
        <mt:AjaxStarRater type="your_mom" id="$author_id" max_points="10">
    </mt:If>

## AjaxThumbRater

Instead of a star rater, this tag will display a thumbs up/down (or plus/minus, etc.) rater.
With this type of rater, there are images for voting an item "up" or "down". A vote "up" is
equal to `1` point, a vote "down" is equal `-1` point.

**Supported arguments**

   * **`type`**
       * See `AjaxStarRater` for details.

   * **`id`**
       * See `AjaxStarRater` for details

   * **`report_icon`**
       * This optional argument will display a third button—a "report" button—when used with
         comment raters. Visitors to your site can click this button to report the comment (for
         abuse, spam, profanity, etc.). When a comment is reported, an email is sent to the
         author of that entry, along with a link to edit the comment in question.

## AjaxRaterOnclickJS

In addition to the convenient star and thumb raters, you can create your own rater. This tag
makes it easier. To enable a rating button (or text link), you need to specify a javascript
`onclick` event. This tag fills in the details.

**Supported arguments**

   * **`type`**
       * See `AjaxStarRater` for details.

   * **`id`**
       * See `AjaxStarRater` for details.

**Example**

This would output a single voting text link for each entry:

    <a href="#" onclick="<$mt:AjaxRaterOnclickJS type="entry" points="1"$>">Like</a>

## AjaxRatingTotalScore

This will display the total score for the item being rated (i.e. adding up the values of all of
the ratings for that item).

## AjaxRatingAverageScore

This will display the average score for the item being rated.

## AjaxRatingVoteCount

This will display the number of votes or ratings that have been submitted for this item.

## AjaxRatingEntryMax

This will display the maximum number of points (stars) for rating entries, as specified in the
plugin settings for that blog.

## AjaxRatingList

A general purpose container tag for displaying listings of "top rated" items in the MT database.

**Supported arguments**

   * **`type`**

       * See `AjaxStarRater` for details.

   * **`sort_by`**

       * Determines which metric is use to rank the results. Allowed value are:
           * `total` (*Default*) - Sorts by total score
           * `average` - Sorts by average score
           * `votes` - Sorts by number of votes

   * **`sort_order`**

       * Defaults to `descend` (highest rating first), but you could also specify `ascend` to
         show the worst rated items first.

   * **`blogs`**

       * By default, the listing contains only items from the blog currently in context. To
         include items from multiple blogs, you can specify a comma-separated list of blog IDs
         or `all` for all blogs.

   * **`show_n`**

       * Use this argument to specify the number of items you want to list (the default is
         **10**).

   * **`hot`**

       * A boolean attribute which, when enabled (`hot="1"`), will generate a list of recently
         "hot" items, that is, a listing based on recent voting activity only. Otherwise, the
         listing will be based on "all time" ratings data.

**Examples**

This creates a listing of **a blog's 10 all-time highest rated entries**, based on **total score**:

    <mt:AjaxRatingList>

This shows the same listing but based on **average score** so that more trafficked/rated
entries don't dominate the listing:

    <mt:AjaxRatingList sort_by="average">

Same as above except for the **worst rated entries** (cue: *sad trombone*):

    <mt:AjaxRatingList sort_by="average" sort_order="ascend">

This creates a listing of the **10 comments receiving the highest number of recent ratings**:

    <mt:AjaxRatingList type="comment" sort_by="votes" hot="1">

This creates a listing of the **top 10 best blogs** on the system:

    <mt:AjaxRatingList type="blog" sort_by="average">

## AjaxRatingEntries

Same as `<mt:AjaxRatingList type="entry">`. Same arguments as `AjaxRatingList`, but the `type`
argument is not required.

## AjaxRatingComments

Same as `<mt:AjaxRatingList type="comment">`. Same arguments as `AjaxRatingList`, but the
`type` argument is not required.

## AjaxRatingPings

Same as `<mt:AjaxRatingList type="trackback">`. Same arguments as `AjaxRatingList`, but the
`type` argument is not required.

## AjaxRatingCategories

Same as `<mt:AjaxRatingList type="category">`. Same arguments as `AjaxRatingList`, but the
`type` argument is not required.

## AjaxRatingBlogs

Same as `<mt:AjaxRatingList type="blog">`. Same arguments as `AjaxRatingList`, but the `type`
argument is not required.

## AjaxRatingAuthors

Same as `<mt:AjaxRatingList type="author">`. Same arguments as `AjaxRatingList`, but the
`type` argument is not required.

## AjaxRatingTags

Same as `<mt:AjaxRatingList type="tag">`. Same arguments as `AjaxRatingList`, but the `type`
argument is not required.

## AjaxRatingCommentMax

This will display the maximum number of points for rating comments, as specified in the plugin
settings for that blog.

## AjaxRatingDefaultThreshold

This will display the default threshold for viewing comments, as specified in the plugin
settings for that blog.

##MTIfAjaxRatingBelowThreshold

This is conditional tag whose contents will be displayed if the comment is below the default
threshold, as specified in the settings. Note that this tag does not apply to user-specified
thresholds (more on those later).

## AjaxRatingRefreshHot

_**WARNING:** You should not use this tag if you have a busy site with high-volume voting_
_activity._

This a special tag, it displays no output. It simply triggers the process of calculating the
list of "hot" items. Note that "hot" list are not tabulated when the listing tags are rebuilt.
For performance reasons, this process happens separately, usually via an MT scheduled task that
runs automatically (approx) once every hour. If, for some reason, you want to manually refresh
to the "hot" list, you can place the `AjaxRatingRefreshHot` tag into an index template and
rebuild it (be sure to uncheck the "rebuild this template with indexes" box!). Again, this
should be used carefully on busy sites, and usually not at all. The "hot" list can also be
refreshed via an included cron script (more on this later).

## AjaxRatingUserVotes

The tag `AjaxRatingUserVotes` is a block tag that outputs a list of the recent objects voted on
by a specific user. Starting in 1.4.1, the sort order is most-recent vote first -- note that
the sorting it based on when the vote was made, NOT the date of the object. This tag is well
suited to an Author archive or user profile page.

## AjaxRatingVoteDistribution

The tag `AjaxRatingVoteDistribution` is a block tag that will provide insight to the votes
received on an object. Within this block tag, access the `score` and `vote` variables to
understand the voting distribution, as in the following example:

    <mt:AjaxRatingVoteDistribution>
        <mt:If name="__first__">
        <ul>
        </mt:If>
            <li><mt:Var name="score"> stars received <mt:Var name="vote"> votes.</li>
        <mt:If name="__last__">
        </ul>
        </mt:If>
    </mt:AjaxRatingVoteDistribution>

As you'll notice, the loop meta variables are also supported, including
`__first__`, `__last__`, `__odd__`, `__even__`, and `__counter__`.

## AjaxRatingTotalVotesInBlog

The tag `AjaxRatingTotalVotesInBlog` is a function tag that will return the total number of ratings on Entries in the current blog.


# (Optional)  JSON Output For Voting Script

(Advanced Feature) Staring in version 1.4.1, the voting script (`mt-vote.cgi`)
can send its responses in JSON format. To request JSON format responses, POSTs
to the voting script must include a `format` parameter set to `json` (`&format=json`).

Example responses:

success:

    {
        "obj_id": "64246",    # object id of object
        "status": "OK",       # OK indicates a successful save
        "vote_count": 29,     # number of votes for this object
        "score": "5",         # score for this vote
        "total_score": 126,   # sum of scores for all votes.
        "obj_type": "entry",  # type of object, usually 'entry'
        "message": "Vote Successful"
    }

error:

    {
        "status": "ERR",
        "message": "You have already voted on this item."
    }

# Get Votes Endpoint

The endpoint `mt-getvotes.cgi` returns the vote summary information for any
given object. Data must be submitted through a POST request and must include
blog ID (`blog_id`), object ID (`obj_id`), and object type (`obj_type`).
Optionally, the `format` parameter can be set to `json`; it is `text` by
default. Example:

    http://myblog.com/mt/plugins/AjaxRating/mt-getvotes.cgi?blog_id=7&obj_type=entry&obj_id=123&format=json

Generates a JSON response such as:

    {
        "obj_type":"entry",
        "obj_id":"123",
        "status":"OK",
        "vote_count":"1",
        "total_score":"5",
        "message":"Vote summary retreived."
    }

Many objects can be retrieved by specifying a comma-separated value for the
`obj_id` argument. (Note that the specified object IDs must all be of the same
object type.) Example:

http://myblog.com/mt/plugins/AjaxRating/mt-getvotes.cgi?blog_id=7&obj_type=entry&obj_id=123,124,125&format=json

Generates a JSON response such as:

    [
        {
            "obj_type":"entry",
            "obj_id":"123",
            "status":"OK",
            "vote_count":"1",
            "total_score":"5",
            "message":"Vote summary retreived."
        },
        {
            "obj_type":"entry",
            "obj_id":"124",
            "status":"OK",
            "vote_count":"9",
            "total_score":"25",
            "message":"Vote summary retreived."
        },
        {
            "obj_type":"entry",
            "obj_id":"125",
            "status":"OK",
            "vote_count":"3",
            "total_score":"4",
            "message":"Vote summary retreived."
        }
    ]

# Data API Interface

Starting with version 1.5.0, Ajax Rating extends the Data API interface of Movable Type 6.

## Entry endpoints

The entry endpoints are exactly like the MT Data API entry endpoints but with `/ajaxrating` appended.

**`GET /sites/:site_id/entries/:entry_id/ajaxrating`**

Use this to retrieve the vote summary for an entry.  Also, if all entries are in the same blog, you can specify multiple entry_ids separated by commas.

**`POST /sites/:site_id/entries/:entry_id/ajaxrating`**

Use this to vote on an entry. Specify the `score` parameter in the request body (e.g. `score=3`).

**`DELETE /sites/:site_id/entries/:entry_id/ajaxrating`**

Use this to remove your vote on an entry.  You can specify multiple, comma-separated entry IDs if in the same blog.

## Comment endpoints

Similarly, the comment endpoints are exactly like the MT Data API comment endpoints but with `/ajaxrating` appended.

**`GET /sites/:site_id/entries/:entry_id/comments/:comment_id/ajaxrating`**

Use this to retrieve the vote summary for a comment.  Also, if all comments are on the same entry, you can specify multiple comment_ids separated by commas.

**`POST /sites/:site_id/entries/:entry_id/comments/:comment_id/ajaxrating`**

Use this to vote on a comment. Specify the `score` parameter and value in the request body.

**`DELETE /sites/:site_id/entries/:entry_id/comments/:comment_id/ajaxrating`**

Use this to remove your vote on a comment.  You can specify multiple, comma-separated comment IDs if on the same entry.

## Generic object type endpoints

The following are used to rate other blog objects (i.e. objects which are children of the blog object). The descriptions are similar to those for the entry endpoints:

    GET    /sites/:site_id/:obj_type/:obj_ids/ajaxrating
    POST   /sites/:site_id/:obj_type/:obj_id/ajaxrating
    DELETE /sites/:site_id/:obj_type/:obj_id/ajaxrating

The following are used to rate other objects which are not children of the blog object. The descriptions are similar to those for the entry endpoints:

    GET    /ajaxrating/:obj_type/:obj_id
    POST   /ajaxrating/:obj_type/:obj_id
    DELETE /ajaxrating/:obj_type/:obj_id

## Vote endpoints

If you have the `vote_id` for a particular vote, you can use the following to get information about a vote or remove it.

    GET    /ajaxrating/votes/:vote_id
    DELETE /ajaxrating/votes/:vote_id
