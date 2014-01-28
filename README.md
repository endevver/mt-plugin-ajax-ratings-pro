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
