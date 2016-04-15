package AjaxRating::DataAPI::Resources {

    use strict;
    use warnings;

    # Add a `ratings` hash to an entry object in the data API.
    sub entry_summary {
        return [
            {
                name => 'ratings',
                from_object => sub {
                    my ($entry) = @_;
                    my $vote_summ
                        = MT->instance->model('ajaxrating_votesummary')->load({
                            obj_type => 'entry',
                            obj_id   => $entry->id,
                        }) or return {
                            avg_score   => 0,
                            total_score => 0,
                            vote_count  => 0,
                        };

                    return {
                        avg_score   => $vote_summ->avg_score,
                        total_score => $vote_summ->total_score,
                        vote_count  => $vote_summ->vote_count,
                    };
                },
                bulk_from_object => sub {
                    my ( $entries, $hashes ) = @_;

                    for my $i ( 0 .. ( scalar(@$entries) - 1 ) ) {
                        my $entry = $entries->[$i];
                        my $vote_summ
                            = MT->instance->model('ajaxrating_votesummary')->load({
                                obj_type => 'entry',
                                obj_id   => $entry->id,
                            });

                        if ($vote_summ) {
                            $hashes->[$i]->{"ratings"} = {
                                avg_score   => $vote_summ->avg_score,
                                total_score => $vote_summ->total_score,
                                vote_count  => $vote_summ->vote_count,
                            };
                        }
                        else {
                            $hashes->[$i]->{"ratings"} = {
                                avg_score   => 0,
                                total_score => 0,
                                vote_count  => 0,
                            };
                        }
                    }
                },
            }
        ];
    }
}

1;

__END__
