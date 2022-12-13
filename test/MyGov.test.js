// test/MyGov.test.js

const { expect } = require('chai');
const { BN, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = require('@openzeppelin/test-helpers/src/constants');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const accounts = [];


const MyGov = artifacts.require('MyGov');



contract('MyGov', (accounts) => {
    function getTimestampSeconds() {
      return Math.floor(Date.now / 1000);
    }

    const max_supply = new BN("10000000");

    // var accountt = new BN(owner, 16);
    // const incr_const = new BN("1");
    // const test_accounts = [];
    // for (let i = 0; i < 300; i++) {
    //     var new_account = new BN(accountt, 16);
    //     test_accounts.push(new_account.toString(16));
    //     accountt = new_account.add(incr_const);
    // };

    console.log(accounts);
    // const tos = account.toString(16);
    beforeEach(async function() {
        this.MyGov = await MyGov.new({ from: accounts[0] });
    });

    // this.MyGov = await MyGov.new({ from: accounts[0] });

    // it('owner already faucet', async function () {
    //     await expectRevert(this.MyGov.faucet({ from : test_accounts[0]}), 'Already taken the faucet token.');
    // });
    // for (let i = 31; i < 32; i++) {
    //     it('new member' + i + ' faucet function', async function () {
    //         const fauc = await this.MyGov.faucet({ from: accounts[i]});

    //         expectEvent(fauc, 'Transfer', { from: ZERO_ADDRESS, to: accounts[i], value: 1});
    //     });
    // }
    it('max supply comparison', async function () {
        expect(await this.MyGov.maxSupply()).to.be.bignumber.equal(max_supply);
    });

    it('returns whether given address is a member', async function () {
        expect(await this.MyGov.isMember(accounts[0])).to.be.equal(true);
    });

    it('owner already faucet', async function () {
        await expectRevert(this.MyGov.faucet({ from : accounts[0]}), 'Already taken the faucet token.');
    });

    for(let i=1; i<accounts.length - 3; i++) {
      it('new member ' + i + ' faucet function', async function () {
        const fauc = await this.MyGov.faucet({from: accounts[i]});
        await expectEvent(fauc, 'Transfer', { from: ZERO_ADDRESS, to: accounts[i], value: BN("1")});

        expect(await this.MyGov.isMember(accounts[i])).to.be.equal(true);

        const blnc = await this.MyGov.balanceOf(accounts[i]);
        expect(blnc.toString()).to.be.equal("1");
        // expect(await this.MyGov.balanceOf(accounts[i])).to.be.equal(BN("1"));
      });
    }

    for(let i=accounts.length - 3; i<accounts.length; i++) {
      it('not member ' + i, async function () {
        expect(await this.MyGov.isMember(accounts[i])).to.be.equal(false);
        const bal = await this.MyGov.balanceOf(accounts[i]);
        console.log('balance of ' + 1 + ': ' + bal.toString());
      });
    }

    it('survey test', async function () {

      for(let index=1; index<4; index++) {
        const fauc = await this.MyGov.faucet({from: accounts[index]});
        await expectEvent(fauc, 'Transfer', { from: ZERO_ADDRESS, to: accounts[index], value: BN("1")});

        expect(await this.MyGov.isMember(accounts[index])).to.be.equal(true);

        var blnc = await this.MyGov.balanceOf(accounts[index]);
        expect(blnc.toString()).to.be.equal("1");

        const transferr = await this.MyGov.transfer(accounts[4], 1, {from: accounts[index]});
        await expectEvent(transferr, 'Transfer', {from: accounts[index], to: accounts[4], value: BN("1")});

        const blncc = await this.MyGov.balanceOf(accounts[index]);
        expect(blncc.toString()).to.be.equal("0");
        
        const member_sender = await this.MyGov.isMember(accounts[index]);
        const member_receiver = await this.MyGov.isMember(accounts[4]);

        expect(member_receiver).to.be.equal(true);
        expect(member_sender).to.be.equal(false);
      }
      
      const surveyer = 4;
      // balance for accounts[4]: 3
      var blncc = await this.MyGov.balanceOf(accounts[surveyer]);
      expect(blncc.toString()).to.be.equal("3");


      const current_time = Math.floor(Date.now() / 1000);
      const deadline = current_time + 5;

      await expectRevert(this.MyGov.submitSurvey("test file", current_time - 50, 3, 2, { from: accounts[0], value: BN('40000000000000000')}), 'not enough token!');
      await expectRevert(this.MyGov.submitSurvey("test file", current_time - 50, 3, 2, { from: accounts[surveyer], value: BN('40000000000000000')}), 'deadline not valid!');
      await expectRevert(this.MyGov.submitSurvey("test file", deadline, 3, 4, { from: accounts[surveyer], value: BN('40000000000000000')}), 'invalid parameters!');
      await expectRevert(this.MyGov.submitSurvey("test file", deadline, 3, 2, { from: accounts[surveyer], value: BN('40000000000000')}), 'not enough ether!');

      const survey = await this.MyGov.submitSurvey("test file", deadline, 3, 2, { from: accounts[surveyer], value: BN('40000000000000000')});
      await expectEvent(survey, 'Survey', {id: BN('0'), deadline: BN(deadline + '')});

      blncc = await this.MyGov.balanceOf(accounts[surveyer]);
      expect(blncc.toString()).to.be.equal("1");


      const num_of_surveys = await this.MyGov.getNoOfSurveys();
      expect(num_of_surveys.toString()).to.be.equal('1');

      const get_survey_info = await this.MyGov.getSurveyInfo(0);
      expect(get_survey_info[0]).to.be.equal('test file');

      const survey_owner = await this.MyGov.getSurveyOwner(0);
      expect(survey_owner.toString()).to.be.equal(accounts[4].toString());

      await expectRevert(this.MyGov.takeSurvey(0, [1, 2], {from: accounts[1]}), 'you are not a member!');
      await expectRevert(this.MyGov.takeSurvey(0, [0, 1, 2], {from: accounts[0]}), 'too much choices!');
      await expectRevert(this.MyGov.takeSurvey(0, [1, 4], {from: accounts[0]}), 'invalid choice detected!');
      
      const survey_taker = await this.MyGov.takeSurvey(0, [0, 2], {from: accounts[0]});
      await expectEvent(survey_taker, 'SurveyTake', {surveyid: BN('0')});
      var active_votes = await this.MyGov.getActiveVotes(accounts[0]);
      expect(active_votes.toString()).to.be.equal('1');
      const results = await this.MyGov.getSurveyResults(0);
      expect(results[0].toString()).to.be.equal('1');
      expect(results[1][0].toString()).to.be.equal('1');
      expect(results[1][1].toString()).to.be.equal('0');
      expect(results[1][0].toString()).to.be.equal('1');


      await expectRevert(this.MyGov.takeSurvey(0, [0, 2], {from: accounts[0]}), 'survey taken before!');
      await expectRevert(this.MyGov.donateMyGovToken(2, { from: accounts[0]}), 'not enough token!');
      await expectRevert(this.MyGov.donateMyGovToken(1, { from: accounts[0]}), 'active vote detected!');
      await new Promise(r => setTimeout(r, 6000));
      await this.MyGov.takeSurvey(0, [0, 2], {from: accounts[4]});
      await expectRevert(this.MyGov.takeSurvey(0, [0, 2], {from: accounts[4]}), 'deadline passed');
      active_votes = await this.MyGov.getActiveVotes(accounts[0]);
      expect(active_votes.toString()).to.be.equal('0');
      const donate_token = await this.MyGov.donateMyGovToken(1, {from: accounts[0]});
      await expectEvent(donate_token, 'Transfer', {from: accounts[0], to: ZERO_ADDRESS, value: BN("1")});

    });

});