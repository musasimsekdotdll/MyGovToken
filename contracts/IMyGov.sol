// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


interface IMyGov {

    event MemberAdd(address indexed member);
    event Project(uint indexed id, uint indexed total_payment, uint deadline);
    event Delegation(uint indexed projectid, address indexed from, address indexed to, uint token);
    event Vote(uint indexed projectid, address indexed voter, bool choice, uint indexed vote_amount, int payment_index);
    event ProjectReservation(uint indexed projectid, uint indexed total_payment);
    event TokenRightsGivenBack(uint indexed post_type, uint indexed id, uint indexed sub_id);
    event Withdrawal(uint indexed projectid, uint indexed index, uint indexed amount);
    event Survey(uint indexed id, uint indexed deadline);
    event Donation(uint indexed post_type, uint indexed amount);
    event SurveyTake(uint indexed surveyid);
}