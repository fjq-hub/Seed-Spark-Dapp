//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

// [X] Anyone can contribute
// [X] End project if targeted contribution amount reached
// [X] Expire project if raised amount not fullfill between deadline
//    & return donated amount to all contributor .
// [X] Owner need to request contributers for withdraw amount. ??????
// [X] Owner can withdraw amount if 50% contributions agree ??????????
// [X] Refund contributions if the project deadline has passed and the goal amount has not been reached or the project is cancelled by creator.

contract Project{

   // Project state
    enum State {
        Fundraising,
        Expired,
        Cancelled,
        Successful
    }

    // Structs
    struct ExtensionRequest{
        string description;
        uint256 newDeadline;
        uint256 noOfVotes;
        mapping(address => bool) voters;
        bool isCompleted;
    }

    // Variables
    address payable public creator;
    address payable public contributer;
    uint256 public minimumContribution;
    uint256 public deadline;
    uint256 public targetContribution; // required to reach at least this much amount
    uint public completeAt;
    uint256 public raisedAmount; // Total raised amount till now
    uint256 public noOfContributers;
    string public projectTitle;
    string public projectDes;
    State public state = State.Fundraising; 
    uint256 public numOfExtensionRequests = 0;
    address[] contributors;

    mapping (address => uint) public contributions;
    mapping (uint256 => ExtensionRequest) public ExtensionRequests;
    
    // Modifiers
    modifier isCreator(){
        require(msg.sender == creator,'You dont have access to perform this operation !');
        _;
    }

    modifier validateExpiry(State _state){
        require(state == _state,'Invalid state');
        require(block.timestamp < deadline,'Deadline has passed !');
        _;
    }

    modifier validateAutoRefund(){
        require(state == State.Expired || state == State.Cancelled);
        _;
    }

    // Events

    // Event that will be emitted whenever funding will be received
    event FundingReceived(address contributor, uint amount, uint currentTotal);
    // Event that will be emitted whenever refund request is successful
    event Refunded(address contributor, uint amount);
    // Event that will be emitted when project get cancelled
    event Cancelled(string description);
    // Event that will be emitted whenever extension request created
    event ExtensionRequestCreated(
        uint256 requestId,
        string description,
        uint256 newDeadline,
        uint256 noOfVotes,
        bool isFundraising
    );
    // Event that will be emitted whenever contributor vote for Extension request
    event ExtensionVote(address voter, uint totalVote);
    // Event that will be emitted when onwer extend project deadline
    event ExtensionSuccessful(
        uint256 requestId,
        string description,
        uint256 newDeadline,
        uint256 noOfVotes,
        bool isCompleted
    );
    // Event that will be emitted when onwer withdraw fund
    event CreatorwithdrawSuccessful(
        uint256 amount,
        address reciptent
    );

    // Event that will be emitted when project expire or get cancelled and refund all contibutors 
    event autoRefunded(
    address indexed contributor,
    uint256 refundedAmount
);


    // @dev Create project
    // @return null

   constructor(
       address _creator,
       uint256 _minimumContribution,
       uint256 _deadline,
       uint256 _targetContribution,
       string memory _projectTitle,
       string memory _projectDes
   ) {
       creator = payable(_creator);
       minimumContribution = _minimumContribution;
       deadline = _deadline;
       targetContribution = _targetContribution;
       projectTitle = _projectTitle;
       projectDes = _projectDes;
       raisedAmount = 0;
   }

    // @dev Anyone can contribute
    // @return null

    function contribute(address _contributor) public validateExpiry(State.Fundraising) payable {
        require(msg.value >= minimumContribution,'Contribution amount is too low !');
        if(contributions[_contributor] == 0){
            noOfContributers++;
            contributors.push(_contributor);
        }
        contributions[_contributor] += msg.value;
        
        raisedAmount += msg.value;
        emit FundingReceived(_contributor,msg.value,raisedAmount);
        checkFundingCompleteOrExpire();
    }

    // @dev complete or expire funding
    // @return null

    function checkFundingCompleteOrExpire() public {
        if(block.timestamp > deadline){
            state = State.Expired; 
        }else if(raisedAmount >= targetContribution){
            state = State.Successful;
            completeAt = block.timestamp; 
        }
    }

    // @dev Get contract current balance
    // @return uint 

    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    // @dev Contributor can request refund at fundraising state
    // @return null

    function requestRefund(uint256 _amount) public validateExpiry(State.Fundraising) {
        require(contributions[msg.sender] >= 0,'You dont have any contributed amount !');
        address payable user = payable(msg.sender);
        if(_amount < contributions[msg.sender]){
            user.transfer(_amount);
            contributions[msg.sender] = contributions[msg.sender] - _amount; 
        }else if(_amount >= contributions[msg.sender]){
            user.transfer(contributions[msg.sender]);
            contributions[msg.sender] = 0;
        }
        uint refundAmount = _amount > contributions[msg.sender] ? _amount : contributions[msg.sender];
        emit Refunded(msg.sender,refundAmount);
    }

    // @dev If project is expired or cancelled all raised amount is refund back to contributions
    // @return null

    function autoRefund() internal validateAutoRefund() {
        for (uint i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            uint amount = contributions[contributor];
            if (amount > 0) {
                // Transfer ether to the contributor's address
                contributions[contributor] = 0;
                payable(contributor).transfer(amount);
                emit autoRefunded(contributor, amount);
            }
        }
    }

    // // @dev Request contributor for withdraw amount
    // // @return null

    function cancelProject(string memory _description) public isCreator() validateExpiry(State.Fundraising) {
        state = State.Cancelled;
        emit Cancelled(_description);
        autoRefund();
    }

    // @dev Request for project extension before 
    // @return null
   
    function createExtensionRequest(string memory _description,uint256 _newDeadline) public isCreator() validateExpiry(State.Fundraising) {
        require(numOfExtensionRequests <= 2, 'You have reached the maximum extension request limit !');
        ExtensionRequest storage newRequest = ExtensionRequests[numOfExtensionRequests];
        numOfExtensionRequests++;

        newRequest.description = _description;
        newRequest.newDeadline = _newDeadline;
        newRequest.noOfVotes = 0;
        newRequest.isCompleted = false;

        emit ExtensionRequestCreated(numOfExtensionRequests,_description, _newDeadline,0,false);
    }

    // @dev contributions can vote for withdraw request
    // @return null

    function voteExtensionRequest(uint256 _requestId) public {
        require(contributions[msg.sender] > 0,'Only contributor can vote !');
        ExtensionRequest storage requestDetails = ExtensionRequests[_requestId];
        require(requestDetails.voters[msg.sender] == false,'You already voted !');
        requestDetails.voters[msg.sender] = true;
        requestDetails.noOfVotes += 1;
        emit ExtensionVote(msg.sender,requestDetails.noOfVotes);
    }

    // @dev Owner can extend project deadline if more than 50% contributions vote for the request
    // @return null

    function projectExtension(uint256 _requestId) isCreator() validateExpiry(State.Fundraising) public{
        ExtensionRequest storage requestDetails = ExtensionRequests[_requestId];
        require(requestDetails.isCompleted == false,'Request already completed');
        require(requestDetails.noOfVotes >= noOfContributers/2,'At least 50% contributor need to vote for this request');
        deadline = requestDetails.newDeadline;
        requestDetails.isCompleted = true;

        emit ExtensionSuccessful(
            _requestId,
            requestDetails.description,
            requestDetails.newDeadline,
            requestDetails.noOfVotes,
            true
        );

    }

    // @dev Owner can withdraw raised amt is project state is successful
    // @return null
    function creatorWithdraw() public isCreator() validateExpiry(State.Successful) payable {
        require(getContractBalance() > 0,'All raisedAmount has been withdrawn !');
        address payable creatorPayable = payable(msg.sender);
        creatorPayable.transfer(getContractBalance());
        raisedAmount = 0;

        emit CreatorwithdrawSuccessful(getContractBalance(),creator);
    }

    // @dev Get contract details
    // @return all the project's details

    function getProjectDetails() public view returns(
    address payable projectStarter,
    uint256 minContribution,
    uint256  projectDeadline,
    uint256 goalAmount, 
    uint completedTime,
    uint256 currentAmount, 
    string memory title,
    string memory desc,
    State currentState,
    uint256 balance
    ){
        projectStarter=creator;
        minContribution=minimumContribution;
        projectDeadline=deadline;
        goalAmount=targetContribution;
        completedTime=completeAt;
        currentAmount=raisedAmount;
        title=projectTitle;
        desc=projectDes;
        currentState=state;
        balance=address(this).balance;
    }

}