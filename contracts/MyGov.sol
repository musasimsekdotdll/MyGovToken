// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "./IMyGov.sol";


struct SurveyProposal {
    uint id;
    string ipfshash;
    uint deadline;
    uint numchoices;
    uint atmostchoice;
    uint numtaken;
    address owner;
    bool tokenRightsGivenBack;

    mapping(address => uint[]) resultsOfMembers;
    mapping(address => bool) memberTakenSurvey; 
    uint[] resultsOfChoices;

}



struct ProjectProposal {
    uint id;
    string ipfshash;
    uint deadline;
    uint[] payment_amounts;
    uint[] payment_schedule;
    uint total_payment; 
    uint balance;
    address owner;
    uint sumOfApprovals;
    bool tokenRightsGivenBack;

    mapping(address => int) numUsedVotes;
    address[] approvals;
    address[] refusals;
    bool funded;
    uint next_payment_index;
    mapping(uint => Project) payments;
    mapping(address => address[]) delegators;
}



struct Project {
    uint id;
    bool tokenRightsGivenBack;
    address[] payment_approvals;
    address[] payment_refusals;
    uint sum_of_approvals;
    mapping(address => int) num_used_votes;
}

contract MyGov is ERC20, IMyGov {

    mapping(address => bool) private _faucets;
    uint private _maxSupply = 10000000;
    mapping(address => bool) private _members;
    uint private _numOfMembers = 0;

    mapping(uint => SurveyProposal) private _surveys;
    uint private _surveySize = 0;
    uint private _activeSurveys = 0;
    mapping(uint => address[]) private _surveyeds;

    mapping(uint => ProjectProposal) _projectProposals;
    uint private _proposalSize = 0;
    mapping(uint => address[]) private voteds;
    uint private _activeProposals = 0;
    uint private _fundedProjects = 0;

    uint private _reservedPayments;
    mapping(address => uint) private _activeVotes;


    modifier enoughTokenForSubmission(address member, uint tokenAmount) {
        require(balanceOf(member) >= tokenAmount, "not enough token!");
        if(balanceOf(member) == tokenAmount) {
            require(_activeVotes[member] == 0, "active vote detected!");
        }
        _;
    }

    modifier onlyFunded(uint projectid) {
        require(_projectProposals[projectid].funded, "project is not funded!");
        _;
    }

    modifier deadlineNotPassed(uint deadline) {
        require(block.timestamp < deadline, "deadline passed");
        _;
    }

    modifier onlyMember(address person) {
        require(isMember(person), "membership not valid");
        _;
    }

    modifier notVoted(address person, uint projectid) {
        int vote_amount = _projectProposals[projectid].numUsedVotes[person];
        require(vote_amount < 1, "already voted/delegated!");
        _;
    }

    
    constructor() ERC20("MyGov", "MGV") {
        faucet();
    }


    function faucet() public {
        require(_faucets[msg.sender] != true, "Already taken the faucet token.");
        require(super.totalSupply() != _maxSupply, "The end of the token supply.");
        
        _faucets[msg.sender] = true;
        makeMember(msg.sender);
        _mint(msg.sender, 1);
        _numOfMembers++;
        emit Transfer(address(this), msg.sender, 1);
    }

    function getActiveVotes(address person) public view returns(uint) {
        return _activeVotes[person];
    }

    function makeMember(address person) private {
        _members[person] = true;
        emit MemberAdd(person);
    }

    function checkMembership(address person) private {
        if(balanceOf(person) == 0) {
            _members[person] = false;
            _numOfMembers--;
        } else if(balanceOf(person) > 0 && !isMember(person)) {
            makeMember(person);
            _numOfMembers++;
        }
    }

    function isMember(address person) public view returns(bool) {
        return _members[person];
    }

    function maxSupply() public view returns(uint) {
        return _maxSupply;
    }


    function submitProjectProposal(
        string memory ipfshash,
        uint votedeadline,
        uint[] memory paymentamounts,
        uint[] memory payschedule
    ) payable public enoughTokenForSubmission(msg.sender, 5) {
        require(msg.value == 0.1 ether, "not enough ether!");
        require(votedeadline > block.timestamp, "deadline not valid");
        require(paymentamounts.length == payschedule.length, "invalid payment amounts/schedules");

        uint currentSchedule = votedeadline;
        for(uint i=0; i<payschedule.length; i++) {
            require(payschedule[i] > currentSchedule, "invalid schedule");
            currentSchedule = payschedule[i];
        }

        super._burn(msg.sender, 5);
        checkMembership(msg.sender);
        uint proposalid = _proposalSize;
        ProjectProposal storage pp = _projectProposals[proposalid];

        pp.id = proposalid;
        pp.ipfshash = ipfshash;
        pp.deadline = votedeadline;
        pp.payment_amounts = paymentamounts;
        pp.payment_schedule = payschedule;

        uint total = 0;
        for(uint i=0; i<paymentamounts.length; i++) {
            total += paymentamounts[i];
        }

        pp.total_payment = total;
        pp.owner = msg.sender;
        pp.funded = false;
        pp.next_payment_index = 0;
        pp.balance = 0;
        pp.balance = 0;

        _proposalSize++;
        _activeProposals++;
        emit Project(proposalid, total, votedeadline);
    }

    function getIsProjectFunded(uint projectid) public view returns(bool funded) {
        funded = _projectProposals[projectid].funded;
    }

    function getProjectOwner(uint projectid) public view returns(address projectowner) {
        projectowner = _projectProposals[projectid].owner;
    }

    function delegateVoteTo(address member, uint projectid) public deadlineNotPassed(_projectProposals[projectid].deadline) {
        int vote_amount = _projectProposals[projectid].numUsedVotes[msg.sender];
        int delegated_vote = _projectProposals[projectid].numUsedVotes[member];
        require(isMember(msg.sender), "you are not a member!");
        require(isMember(member), "delegated to a nonmember");
        require(vote_amount < 1, "you already voted/delegated your vote!");
        require(delegated_vote < 1, "delegated member already voted!");

        vote_amount--;
        _projectProposals[projectid].numUsedVotes[msg.sender] = 1;
        _projectProposals[projectid].numUsedVotes[member] += vote_amount;
        for(uint i=0; i<_projectProposals[projectid].payment_schedule.length; i++) {
            _projectProposals[projectid].payments[i].num_used_votes[msg.sender] = 1;
            _projectProposals[projectid].payments[i].num_used_votes[member] += vote_amount;
        }

        _projectProposals[projectid].delegators[member].push(msg.sender);
        uint token_amount = uint(-(vote_amount));
        emit Delegation(projectid, msg.sender, member, token_amount);
    }

    function voteForProjectProposal(uint projectid, bool choice) public
        onlyMember(msg.sender)
        deadlineNotPassed(_projectProposals[projectid].deadline)
        notVoted(msg.sender, projectid) {

            uint vote_amount = uint(1 - _projectProposals[projectid].numUsedVotes[msg.sender]);
            _projectProposals[projectid].numUsedVotes[msg.sender] = 1;
            if(choice) {
                _projectProposals[projectid].approvals.push(msg.sender);
                _projectProposals[projectid].sumOfApprovals += vote_amount;
            } else {
                _projectProposals[projectid].refusals.push(msg.sender);
            }

            _activeVotes[msg.sender]++; 
            for(uint i=0; i<_projectProposals[projectid].delegators[msg.sender].length; i++) {
                address delegator = _projectProposals[projectid].delegators[msg.sender][i];
                _activeVotes[delegator]++;
            }

            emit Vote(projectid, msg.sender, choice, vote_amount, -1);
    }

    function reserveProjectGrant(uint projectid) public {
        require(_projectProposals[projectid].owner == msg.sender, "you are not the owner!");
        require(address(this).balance >= _reservedPayments + _projectProposals[projectid].total_payment, "contract balance is not enough");
        require(_projectProposals[projectid].sumOfApprovals * 10 > _numOfMembers, "at least 1/10 must approve a proposal");
        require(!_projectProposals[projectid].funded, "project is already funded");

        if(block.timestamp > _projectProposals[projectid].deadline && !_projectProposals[projectid].tokenRightsGivenBack) {
            _projectProposals[projectid].tokenRightsGivenBack = true;
            giveBackTokenRightProjectProposal(projectid);
            _activeProposals--;
        }

        require(block.timestamp <= _projectProposals[projectid].deadline, "deadline passed");
        _projectProposals[projectid].funded = true;
        _reservedPayments += _projectProposals[projectid].total_payment;
        giveBackTokenRightProjectProposal(projectid);
        _activeProposals--;
        _fundedProjects++;

        emit ProjectReservation(projectid, _projectProposals[projectid].total_payment);
    }

    function giveBackTokenRightProjectPayment(uint projectid, uint payment_index) private {
        uint j = 0;
        while(j < _projectProposals[projectid].payments[payment_index].payment_approvals.length) {
            address voter = _projectProposals[projectid].payments[payment_index].payment_approvals[j];
            for(uint i=0; i<_projectProposals[projectid].delegators[voter].length; i++) {
                address delegator = _projectProposals[projectid].delegators[voter][i];
                _activeVotes[delegator]--;
            }
            _activeVotes[voter]--;
            j++;
        }

        j = 0;
        while(j < _projectProposals[projectid].payments[payment_index].payment_refusals.length) {
            address voter = _projectProposals[projectid].payments[payment_index].payment_refusals[j];
            for(uint i=0; i<_projectProposals[projectid].delegators[voter].length; i++) {
                address delegator = _projectProposals[projectid].delegators[voter][i];
                _activeVotes[delegator]--;
            }
            _activeVotes[voter]--;
            j++;
        }

        emit TokenRightsGivenBack(1, projectid, payment_index);
    }

    function giveBackTokenRightProjectProposal(uint projectid) private {
        uint j = 0;
        while(j < _projectProposals[projectid].approvals.length) {
            address voter = _projectProposals[projectid].approvals[j];
            for(uint i=0; i<_projectProposals[projectid].delegators[voter].length; i++) {
                address delegator = _projectProposals[projectid].delegators[voter][i];
                _activeVotes[delegator]--;
            }
            _activeVotes[voter]--;
            j++;
        }

        j = 0;
        while(j < _projectProposals[projectid].refusals.length) {
            address voter = _projectProposals[projectid].refusals[j];
            for(uint i=0; i<_projectProposals[projectid].delegators[voter].length; i++) {
                address delegator = _projectProposals[projectid].delegators[voter][i];
                _activeVotes[delegator]--;
            }
            _activeVotes[voter]--;
            j++;
        }

        emit TokenRightsGivenBack(0, projectid, 0);
    }

    function checkPaymentVotes(uint projectid, uint payment_index) private view returns(bool) {
        return _projectProposals[projectid].payments[payment_index].sum_of_approvals * 100 >= _numOfMembers;
    }

    function voteForProjectPayment(uint projectid, bool choice) public onlyMember(msg.sender) onlyFunded(projectid) {
        address sender = msg.sender;
        int index = findNextPaymentSchedule(projectid);
        require(index >= 0, "project is not funded");
        uint next_payment = uint(index);
        require(_projectProposals[projectid].payments[next_payment].num_used_votes[sender] < 1, "you voted already");
        int vote_amount;

        if(choice) {
            _projectProposals[projectid].payments[next_payment].payment_approvals.push(sender);
            vote_amount = 1 - _projectProposals[projectid].payments[next_payment].num_used_votes[sender];
            _projectProposals[projectid].payments[next_payment].sum_of_approvals += uint(vote_amount);
        } else {
            _projectProposals[projectid].payments[next_payment].payment_refusals.push(sender);
        }

        _projectProposals[projectid].payments[next_payment].num_used_votes[sender] = 1;

        _activeVotes[msg.sender]++; 
        for(uint i=0; i<_projectProposals[projectid].delegators[msg.sender].length; i++) {
            address delegator = _projectProposals[projectid].delegators[msg.sender][i];
            _activeVotes[delegator]++;
        }

        vote_amount = 1 - _projectProposals[projectid].payments[next_payment].num_used_votes[sender];
        emit Vote(projectid, msg.sender, choice, uint(vote_amount), index);
    }

    function findNextPaymentSchedule(uint projectid) public returns(int) {
        uint index = _projectProposals[projectid].next_payment_index;
        uint timestamp = block.timestamp;
        uint skipped_payments = 0;
        while(index < _projectProposals[projectid].payment_schedule.length && 
                (_projectProposals[projectid].payment_schedule[index] <= timestamp)) {

            if(!checkPaymentVotes(projectid, index)) {
                cancelProject(projectid);
                return -1;
            }
            skipped_payments += _projectProposals[projectid].payment_amounts[index];
            index++;
            giveBackTokenRightProjectPayment(projectid, index);
        }

        require(index < _projectProposals[projectid].payment_schedule.length, "project ended");
        _projectProposals[projectid].next_payment_index = index;
        _reservedPayments -= skipped_payments;
        return int(index);
    }

    function withdrawProjectPayment(uint projectid) public payable onlyFunded(projectid) {
        require(block.timestamp > _projectProposals[projectid].deadline, "time has not come yet");
        require(_projectProposals[projectid].owner == msg.sender, "you are not the owner of the project");
        int index = findNextPaymentSchedule(projectid);
        require(index >= 0, "project is not funded");
        uint payment_index = uint(index);
        require(payment_index < _projectProposals[projectid].payment_schedule.length, "project closed!");

        require(_projectProposals[projectid].payments[payment_index].sum_of_approvals * 100 > _numOfMembers, "vote not passed!");
        uint payment_amount = _projectProposals[projectid].payment_amounts[payment_index];
        _projectProposals[projectid].next_payment_index = payment_index + 1;

        _reservedPayments -= payment_amount;
        _projectProposals[projectid].balance += payment_amount;
        
        giveBackTokenRightProjectPayment(projectid, payment_index);
        _projectProposals[projectid].payments[payment_index].tokenRightsGivenBack = true;

        if(payment_index == _projectProposals[projectid].payment_amounts.length - 1) {
            _projectProposals[projectid].funded = false;
            _activeProposals--;
            _fundedProjects--;
        }

        address owner = msg.sender;
        bool result = payable(owner).send(payment_amount);
        require(result, "payment failed, try again later.");

        emit Withdrawal(projectid, payment_index, payment_amount);
    }

    function cancelProject(uint projectid) private {
        uint remaining = _projectProposals[projectid].total_payment - _projectProposals[projectid].balance;
        _reservedPayments -= remaining;
        _projectProposals[projectid].funded = false;
        _activeProposals--;
        _fundedProjects--;
    }

    function getProjectInfo(uint projectid) public view returns(
        string memory ipfshash,
        uint votedeadline,
        uint[] memory paymentamounts,
        uint[] memory payschedule
    ) {
        ipfshash = _projectProposals[projectid].ipfshash;
        votedeadline = _projectProposals[projectid].deadline;
        paymentamounts = _projectProposals[projectid].payment_amounts;
        payschedule = _projectProposals[projectid].payment_schedule;
    }

    function getNoOfProjectProposals() public view returns(uint numproposals) {
        numproposals = _activeProposals;
    }

    function getNoOfFundedProjects() public view returns(uint numfunded) {
        numfunded = _fundedProjects;
    }

    function getEtherReceivedByProject(uint projectid) public view returns(uint amount) {
        amount = _projectProposals[projectid].balance;
    }

    function getProjectNextPayment(uint projectid) public view returns(uint next) {
        next = _projectProposals[projectid].payment_schedule[_projectProposals[projectid].next_payment_index];
    }

    
    function submitSurvey(string memory ipfshash, uint deadline, uint numchoices, uint atmostchoice) payable public enoughTokenForSubmission(msg.sender, 2) returns(uint surveyid) {
        require(msg.value == 0.04 ether, "not enough ether!");
        require(deadline > block.timestamp, "deadline not valid!");
        require(atmostchoice <= numchoices, "invalid parameters!");

        super._burn(msg.sender, 2);
        checkMembership(msg.sender);
        surveyid = _surveySize;
        SurveyProposal storage s = _surveys[surveyid];

        s.id = surveyid;
        s.ipfshash = ipfshash;
        s.deadline = deadline;
        s.numchoices = numchoices;
        s.atmostchoice = atmostchoice;
        s.numtaken = 0;
        s.owner = msg.sender;
        for(uint i=0; i<numchoices; i++) {
            s.resultsOfChoices.push(0);
        }

        _surveySize++;
        _activeSurveys++;

        emit Survey(surveyid, deadline);
        return surveyid;
    }

    function getNoOfSurveys() public view returns(uint numsurveys) {
        numsurveys = _activeSurveys;
    }
    
    function transfer(address to, uint256 amount) public override enoughTokenForSubmission(msg.sender, amount) returns(bool) {
        address owner = _msgSender();
        super._transfer(owner, to, amount);
        checkMembership(msg.sender);
        checkMembership(to);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override enoughTokenForSubmission(from, amount) returns (bool) {
        address spender = _msgSender();
        super._spendAllowance(from, spender, amount);
        super._transfer(from, to, amount);
        checkMembership(from);
        checkMembership(to);
        return true;
    }

    function donateEther() payable public {
        require(msg.value > 0 wei, "zero wei not acceptable");
        emit Donation(0, msg.value);
    }

    function donateMyGovToken(uint amount) public enoughTokenForSubmission(msg.sender, amount) {
        super._burn(msg.sender, amount);
        emit Donation(1, amount);
    }

    function getSurveyInfo(uint surveyid) public view returns(string memory ipfshash, uint deadline, uint numchoices, uint atmostchoice) {
        ipfshash = _surveys[surveyid].ipfshash;
        deadline = _surveys[surveyid].deadline;
        numchoices = _surveys[surveyid].numchoices;
        atmostchoice = _surveys[surveyid].atmostchoice;
    }

    function getSurveyOwner(uint surveyid) public view returns(address surveyowner) {
        surveyowner = _surveys[surveyid].owner;
    }

    function giveBackTokenRight(uint surveyid) private returns(uint) {
        uint j = 0;
        while(j < _surveys[surveyid].numtaken) {
            address voter = _surveyeds[surveyid][j];
            _activeVotes[voter]--;
            j++;
        }

        emit TokenRightsGivenBack(2, surveyid, 0);
        return j;
    }

    function takeSurvey(uint surveyid, uint[] calldata choices) public {
        require(isMember(msg.sender), "you are not a member!");
        require(choices.length <= _surveys[surveyid].atmostchoice, "too much choices!");
        require(!_surveys[surveyid].memberTakenSurvey[msg.sender], "survey taken before!");

        if(_surveys[surveyid].deadline <= block.timestamp && !_surveys[surveyid].tokenRightsGivenBack) {
            _surveys[surveyid].tokenRightsGivenBack = true;
            giveBackTokenRight(surveyid);
            return;
        }

        require(_surveys[surveyid].deadline >= block.timestamp, "deadline passed");

        uint j = 0;
        while(j != choices.length) {
            require(choices[j] < _surveys[surveyid].numchoices, "invalid choice detected!");
            require(choices[j] >= 0, "invalid choice detected!");
            j++;
        }

        _activeVotes[msg.sender]++;
        
        _surveys[surveyid].numtaken++;
        _surveys[surveyid].resultsOfMembers[msg.sender] = choices;

        j = 0;
        while(j != choices.length) {
            _surveys[surveyid].resultsOfChoices[choices[j]]++;
            j++;
        }

        _surveys[surveyid].memberTakenSurvey[msg.sender] = true;
        _surveyeds[surveyid].push(msg.sender);

        emit SurveyTake(surveyid);
    }

    function getSurveyResults(uint surveyid) public view returns(uint numtaken, uint[] memory results) {
        numtaken = _surveys[surveyid].numtaken;
        results = _surveys[surveyid].resultsOfChoices;
    }
}
