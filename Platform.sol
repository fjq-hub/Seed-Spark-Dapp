//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import './Project.sol';
import './SeedToken.sol';

contract Platform{

// [X] Anyone can start a funding project .
// [X] Get All project list
// [X]  contribute amount
address public owner = msg.sender;
SeedToken seedToken;

event ProjectStarted(
    address projectContractAddress ,
    address creator,
    uint256 minContribution,
    uint256 projectDeadline,
    uint256 goalAmount,
    uint256 currentAmount,
    uint256 noOfContributors,
    string title,
    string desc,
    uint256 currentState
);

event ContributionReceived(
   address projectAddress,
   uint256 contributedAmount,
   address indexed contributor
);

event ProjectBalanceWithdrawed(
   address projectAddress,
   address creator
);

event ProjectCanceled(
   address projectAddress,
   address creator,
   string description
);

event ExtensionRequested(
   address projectAddress,
   address creator,
   string description
);

event ExtensionVoted(
   address projectAddress,
   address voter
);

event ExtensionSuccessful(
   address projectAddress
);

event Refunded(
   address projectAddress,
   uint256 amount,
   address contributer
);

 Project[] private projects;

  // @dev Anyone can start a fund rising
 // @return null

function createProject(
    uint256 minimumContribution,
    uint256 deadline,
    uint256 targetContribution, // in ETH
    string memory projectTitle,
    string memory projectDesc,
    uint256 numST
 ) public {
   // require 1/10000 of the target Contribution
   require(numST >= targetContribution/100, 'Committed Seed Tokens not enough!');
   
   seedToken._transferFrom(msg.sender, owner, numST);
   Project newProject = new Project(msg.sender,minimumContribution,deadline,targetContribution,projectTitle,projectDesc);
   projects.push(newProject);
 
 emit ProjectStarted(
    address(newProject) ,
    msg.sender,
    minimumContribution,
    deadline,
    targetContribution,
    0,
    0,
    projectTitle,
    projectDesc,
    0
 );

 }



 // @dev Get projects list
// @return array

function returnAllProjects() external view returns(Project[] memory){
   return projects;
}

// @dev User can contribute
// @return null
function contribute(address _projectAddress) public payable{
   // Call function
   Project(_projectAddress).contribute{value:msg.value}(msg.sender);
   // Reward contributer
   // Reward is 1/20000 to contribur amount
   uint256 tokens = msg.value / 10 ^ 16;
   seedToken._transferFrom(owner, msg.sender, tokens / (2 * (10 ^ 4)));
   // Trigger event 
   emit ContributionReceived(_projectAddress,msg.value,msg.sender);
}

// Check Expiry
function checkProjectState() public {
   for (uint i = 0; i < projects.length; i++) {
      projects[i].checkFundingCompleteOrExpire();
   }
}

// project owner withdraw money
function ownerWithdraw(address _projectAddress) public {
   Project(_projectAddress).creatorWithdraw();
   emit ProjectBalanceWithdrawed(_projectAddress, msg.sender);
}

// cancel project
function cancelProject(address _projectAddress, string memory _description) public {
   Project(_projectAddress).cancelProject(_description);
   emit ProjectCanceled(_projectAddress, msg.sender, _description);
}

// request for extending the project
function createExtensionRequest(string memory _description, uint256 _newDeadline, address _projectAddress) public {
   Project(_projectAddress).createExtensionRequest(_description, _newDeadline);
   emit ExtensionRequested(_projectAddress, msg.sender, _description);
}

// vote for extension
function voteExtensionRequest(uint256 _requestId, address _projectAddress) public{
   Project(_projectAddress).voteExtensionRequest(_requestId);
   emit ExtensionVoted(_projectAddress, msg.sender);
}

// extension 
function projectExtension(uint256 _requestId, address _projectAddress) public {
   Project(_projectAddress).projectExtension(_requestId);
   emit ExtensionSuccessful(_projectAddress);
}

// request for refund
function requestRefund(uint256 _amount, address _projectAddress) public{
   Project(_projectAddress).requestRefund(_amount);
   // give back the rewards
   uint256 tokens = _amount / 10 ^ 16;
   seedToken._transferFrom(msg.sender, owner, tokens / (2 * (10^4)));
   emit Refunded(_projectAddress, _amount, msg.sender);
}

function getProjectDetails(address _projectAddress) public view{
   Project(_projectAddress).getProjectDetails();
}

}