// Ported from gpui-kit 0.8.1: crates/story/src/stories/list_story.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import story.stories.ListStory.Company;
import story.stories.ListStory.CompanyListDelegate;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of the story gallery's `list_story.rs`
 * (`samples/story`).
 */
class StoryListTest extends TestCase {

    function testSearchingAndRefreshingReplaceCompanyGroups() {
        final companies = [for (pair in [['Acme', 'Software'], ['Books', 'Retail'], ['Atlas', 'Software']]) {
            final company = new Company();
            company.name = pair[0];
            company.industry = pair[1];
            company;
        }];
        final delegate = new CompanyListDelegate();
        delegate.companies = companies;

        for (step in [
            {query: '', expected: [['Acme', 'Atlas'], ['Books']]},
            {query: 'ACME', expected: [['Acme'], []]},
            {query: 'missing', expected: [[], []]},
            {query: '', expected: [['Acme', 'Atlas'], ['Books']]},
        ]) {
            delegate.prepare(step.query);
            assertEquals('Software,Retail', delegate.industries.join(','));
            assertEquals(delegate.industries.length, delegate.matchedCompanies.length);
            final names = [for (companies in delegate.matchedCompanies) [for (company in companies) company.name].join(',')].join('|');
            assertEquals([for (group in step.expected) group.join(',')].join('|'), names);
        }
        // Loading more data also rebuilds the current query; it must not duplicate old rows.
        delegate.extendMore(0);
        var total = 0;
        for (companies in delegate.matchedCompanies) total += companies.length;
        assertEquals(3, total);
    }

}
