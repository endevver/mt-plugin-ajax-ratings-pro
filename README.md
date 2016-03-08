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

## AjaxRatingUserVotes

The tag `AjaxRatingUserVotes` is a block tag that outputs a list of
the recent objects voted on by a specific user. Starting in 1.4.1, the sort
order is most-recent vote first -- note that the sorting it based on when the
vote was made, NOT the date of the object.  This tag is well suited to an
Author archive or user profile page.

## AjaxRatingVoteDistribution

The tag `AjaxRatingVoteDistribution` is a block tag that will provide insight
to the votes received on an object. Within this block tag, access the `score`
and `vote` variables to understand the voting distribution, as in the
following example:

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
