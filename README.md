# xlRan

The global litigation funding market exceeds USD 13.6 billion annually and continues to experience steady growth. One of the primary challenges within this industry is accurately predicting case outcomes in favor of the plaintiff. We are addressing this challenge by introducing xlRan, a platform developed on the efficient [StarkNet network](https://www.starknet.io/), enabling us to leverage public staking mechanisms and market dynamics. This approach empowers us to generate confidence scores and ranges for potential outcomes of specific cases while maintaining the confidentiality of each case.

# How xlRan Operates

All attorneys must first receive approval from a [DAO](https://www.investopedia.com/tech/what-dao/) before they are permitted to stake their reputation on case outcomes. This is to ensure legitimacy and prevent individuals from creating duplicate accounts in the event their predictions are inaccurate.

### Membership Requirements

To join the Lawyer Approval DAO, members must stake a minimum number of xlRan tokens that represent their voting power within the platform. By doing so, members contribute to the decision-making process for approving attorneys.

As part of the attorney membership process, candidates are required to upload their credentials in advance. These credentials are reviewed by the DAO members to verify that the membership requirements are met and maintained. Voting power within the DAO is proportional to the amount of staked xlRan tokens.

Upon an attorney's approval, DAO members who have voted for that candidate will be entitled to a small fixed percentage of the attorney's earnings on the platform. This ensures that members are rewarded for their active participation and decision-making contributions.

### Uploading Cases

Once you have been approved as a lawyer, you can start uploading detailed case summaries and their locations. These summaries must contain enough information for predictions to be made, but please make sure to remove any personal details to ensure anonymity. Please note that uploading any personal details with the case summary will result in an immediate lifetime ban from the platform.

### Case Oracle

The status of each case is updated by the lawyer. This status is then voted on upon by the DAO. (Incomplete section, case oracle is still under design).

### Lawyer Reputation

The reputation of lawyers is intricately tied to their ability to correctly predict case outcomes. This reputation metric offers valuable insights into the track record and expertise of legal professionals, fostering transparency and accountability in the legal domain.

### Lawyer Cache Case

Lawyers can cache and predict potential case outcomes, offering a unique opportunity for investors to support packages of these cases. By funding these case packages, investors not only stand to reap the rewards of successful cases but also contribute to the growth and success of legal professionals. Investor's shall receive 30% of the case settlment value incase the case is successful.

Furthermore, a portion of the rewards generated from successful case outcomes is distributed to the lawyer, creating an incentivized ecosystem that fosters attorney-client collaboration. Performance records are maintained over the blockchain for each lawyer, providing a comprehensive overview of their track record, while the amount of reputation they can stake is carefully regulated to ensure a fair and equitable system. 

### DAO Fees and Oracle Voting

In the DAO, members have the autonomy to vote on which case oracle to utilize for each specific case. Additionally, they have the authority to vote and determine the percentage of settlement funds allocated as a reward for each member who votes to add the attorney to the system.

## Setting up the repository

To set up the repository, you'll need to use asdf, a CLI tool that manages multiple language runtime versions on a per-project basis, and install Cairo, the programming language in which Starkent smart contracts are written. Follow these steps to get started:

1. **Setting up asdf:**
   To install asdf, the recommended tool for installing Cairo, refer to the installation guide at https://asdf-vm.com/guide/getting-started.html.

2. **Installing Cairo and Scarb:**
   In your terminal, run the following commands to install Cairo and Scarb (Scarb is Cairo's build toolchain and package manager):
   ```console
   asdf plugin add scarb
   asdf install scarb 2.6.3
   asdf global scarb 2.6.3
   ```

3. **Building the program:**
   Navigate to the xlran folder in the git repository and use the following command to build the program:
   ```console
   scarb build
   ```

4. **Running the test suite:**
   To run the test suite, execute the following command in the xlran folder:
   ```console
   scarb test
   ```

## Contributing and Test Driven Development

At xlRan, we adhere to a test driven development approach for the smart contracts. Consequently, you may observe that certain test cases are currently not passing. This is because we prioritize writing test cases before the actual code. Therefore, any contributions adding new planned features, altering existing features to address bugs, or extending functionality must ensure that the respective test cases pass. The test suite can be found in the [test folder](https://github.com/tanmaymunjal/xlRan/tree/main/xlran/tests).

The current test cases for the contracts do the following:

**test_register_lawyer**: Test registering a lawyer and verifying initial state.

**test_dao_member_voting**: Test DAO member voting for a lawyer.

**test_lawyer_approval**: Test the approval process for a lawyer.

**test_register_case**: Test registering a case and verifying its initial state.

**test_ban_lawyer**: Test banning a lawyer and verifying the banned state.

**test_unstaking**: Test unstaking DAO tokens after lawyer approval.

**test_no_double_voting**: Test preventing double voting and unstaking without approval.

**test_dao_vote_on_settlement_oracle**: Test DAO voting on a settlement oracle for a case.

**test_case_settlement**: Test case settlement process and oracle result verification.

**test_case_settlement_post_deadline**: Test case settlement after the deadline.

**test_post_case_money_distribution**: Test money distribution to investors after case resolution.

**test_cant_over_invest**: Test preventing over-investment in a case.

**test_cant_invest_after_deadline**: Test preventing investment after the deadline.

**test_voting_on_dao_fees**: Test DAO voting on fees and verifying the declared fees.

**test_multiple_lawyer_nultiple_voter_scenario**: Test multiple lawyers and voters scenario with approval thresholds.

**test_prevent_duplicate_lawyer_registration**: Test preventing duplicate lawyer registration.

**test_case_registration_with_invalid_parameters**: Test case registration with invalid parameters.

**test_oracle_voting_after_case_resolution**: Test preventing oracle voting after case resolution.

**test_multiple_investors_distribution**: Test money distribution among multiple investors after case resolution.

**test_banned_lawyer_restrictions**: Test restrictions on banned lawyers.

**test_unstaking_with_pending_votes**: Test preventing unstaking with pending votes.

We plan to extend the test suite very soon and add many more to properly test the smart contracts and ensure they are completely bug-free.

## AI Prompting

AI technology plays a pivotal role in modern software development. Within our ai_prompt_gen folder, you'll find a Python file and two text documents. These files contain documentation for Cairo and Starknet, as indicated by their titles. Leveraging these resources, you can prompt GPT4, Claude Sonnet, or other LLMs as you venture into coding for Starknet. Additionally, you have the flexibility to modify configuration values in the Python file to specify the sections of documentation to scrape. This optimization can help reduce context size tokens, providing improved accuracy and allowing for the utilization of a greater diversity of models.

