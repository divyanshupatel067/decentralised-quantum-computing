// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct QuantumProvider {
        address provider;
        string name;
        uint256 qubits;
        uint256 executionTime; // in seconds
        uint256 pricePerExecution;
        bool isActive;
        uint256 reputation;
        uint256 totalExecutions;
    }
    
    struct QuantumJob {
        uint256 jobId;
        address client;
        address provider;
        string algorithmHash; // IPFS hash of quantum algorithm
        uint256 requiredQubits;
        uint256 payment;
        uint256 submissionTime;
        uint256 executionDeadline;
        JobStatus status;
        string resultHash; // IPFS hash of execution result
        bool paymentReleased;
    }
    
    struct QuantumAlgorithm {
        address creator;
        string name;
        string algorithmHash; // IPFS hash
        uint256 minQubits;
        uint256 estimatedTime;
        uint256 usageCount;
        uint256 price;
        bool isPublic;
    }
    
    enum JobStatus {
        Pending,
        Assigned,
        Executing,
        Completed,
        Failed,
        Disputed
    }
    
    mapping(address => QuantumProvider) public quantumProviders;
    mapping(uint256 => QuantumJob) public quantumJobs;
    mapping(string => QuantumAlgorithm) public quantumAlgorithms;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public providerJobs;
    
    address[] public registeredProviders;
    uint256 public jobCounter;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 3; // 3% platform fee
    uint256 public constant DISPUTE_RESOLUTION_TIME = 7 days;
    
    event ProviderRegistered(
        address indexed provider,
        string name,
        uint256 qubits,
        uint256 pricePerExecution
    );
    
    event JobSubmitted(
        uint256 indexed jobId,
        address indexed client,
        string algorithmHash,
        uint256 requiredQubits,
        uint256 payment
    );
    
    event JobAssigned(
        uint256 indexed jobId,
        address indexed provider,
        uint256 deadline
    );
    
    event JobCompleted(
        uint256 indexed jobId,
        address indexed provider,
        string resultHash
    );
    
    event AlgorithmRegistered(
        string indexed algorithmHash,
        address indexed creator,
        string name,
        uint256 minQubits
    );
    
    event PaymentReleased(
        uint256 indexed jobId,
        address indexed provider,
        uint256 amount
    );
    
    modifier onlyProvider() {
        require(
            quantumProviders[msg.sender].provider != address(0),
            "Only registered providers can perform this action"
        );
        _;
    }
    
    modifier validJob(uint256 _jobId) {
        require(_jobId < jobCounter, "Job does not exist");
        _;
    }
    
    modifier onlyJobClient(uint256 _jobId) {
        require(
            quantumJobs[_jobId].client == msg.sender,
            "Only job client can perform this action"
        );
        _;
    }
    
    modifier onlyAssignedProvider(uint256 _jobId) {
        require(
            quantumJobs[_jobId].provider == msg.sender,
            "Only assigned provider can perform this action"
        );
        _;
    }
    
    // Core Function 1: Register Quantum Computing Provider
    function registerProvider(
        string memory _name,
        uint256 _qubits,
        uint256 _executionTime,
        uint256 _pricePerExecution
    ) external {
        require(_qubits > 0, "Qubits must be greater than 0");
        require(_executionTime > 0, "Execution time must be greater than 0");
        require(_pricePerExecution > 0, "Price must be greater than 0");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(
            quantumProviders[msg.sender].provider == address(0),
            "Provider already registered"
        );
        
        quantumProviders[msg.sender] = QuantumProvider({
            provider: msg.sender,
            name: _name,
            qubits: _qubits,
            executionTime: _executionTime,
            pricePerExecution: _pricePerExecution,
            isActive: true,
            reputation: 100, // Starting reputation
            totalExecutions: 0
        });
        
        registeredProviders.push(msg.sender);
        
        emit ProviderRegistered(msg.sender, _name, _qubits, _pricePerExecution);
    }
    
    // Core Function 2: Submit Quantum Computing Job
    function submitJob(
        string memory _algorithmHash,
        uint256 _requiredQubits,
        uint256 _executionDeadlineHours
    ) external payable {
        require(_requiredQubits > 0, "Required qubits must be greater than 0");
        require(_executionDeadlineHours > 0, "Deadline must be greater than 0");
        require(msg.value > 0, "Payment must be provided");
        require(bytes(_algorithmHash).length > 0, "Algorithm hash cannot be empty");
        
        uint256 executionDeadline = block.timestamp + (_executionDeadlineHours * 1 hours);
        
        quantumJobs[jobCounter] = QuantumJob({
            jobId: jobCounter,
            client: msg.sender,
            provider: address(0),
            algorithmHash: _algorithmHash,
            requiredQubits: _requiredQubits,
            payment: msg.value,
            submissionTime: block.timestamp,
            executionDeadline: executionDeadline,
            status: JobStatus.Pending,
            resultHash: "",
            paymentReleased: false
        });
        
        clientJobs[msg.sender].push(jobCounter);
        
        emit JobSubmitted(
            jobCounter,
            msg.sender,
            _algorithmHash,
            _requiredQubits,
            msg.value
        );
        
        jobCounter++;
    }
    
    // Core Function 3: Execute Quantum Job (Provider accepts and completes job)
    function acceptAndExecuteJob(uint256 _jobId, string memory _resultHash) 
        external 
        onlyProvider 
        validJob(_jobId) 
    {
        QuantumJob storage job = quantumJobs[_jobId];
        QuantumProvider storage provider = quantumProviders[msg.sender];
        
        require(job.status == JobStatus.Pending, "Job not available");
        require(
            provider.qubits >= job.requiredQubits,
            "Insufficient quantum computing capacity"
        );
        require(
            block.timestamp < job.executionDeadline,
            "Job deadline has passed"
        );
        require(provider.isActive, "Provider is not active");
        require(bytes(_resultHash).length > 0, "Result hash cannot be empty");
        
        // Assign job to provider
        job.provider = msg.sender;
        job.status = JobStatus.Executing;
        providerJobs[msg.sender].push(_jobId);
        
        emit JobAssigned(_jobId, msg.sender, job.executionDeadline);
        
        // Complete job execution (in real implementation, this would be separate)
        job.resultHash = _resultHash;
        job.status = JobStatus.Completed;
        
        // Update provider statistics
        provider.totalExecutions++;
        
        emit JobCompleted(_jobId, msg.sender, _resultHash);
        
        // Auto-release payment for completed jobs
        _releasePayment(_jobId);
    }
    
    // Internal function to release payment
    function _releasePayment(uint256 _jobId) internal {
        QuantumJob storage job = quantumJobs[_jobId];
        QuantumProvider storage provider = quantumProviders[job.provider];
        
        require(!job.paymentReleased, "Payment already released");
        require(job.status == JobStatus.Completed, "Job not completed");
        
        job.paymentReleased = true;
        
        // Calculate platform fee
        uint256 platformFee = (job.payment * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 providerPayment = job.payment - platformFee;
        
        // Update provider reputation based on timely completion
        if (block.timestamp <= job.executionDeadline) {
            provider.reputation = provider.reputation < 200 ? provider.reputation + 1 : 200;
        }
        
        // Transfer payment to provider
        payable(job.provider).transfer(providerPayment);
        
        emit PaymentReleased(_jobId, job.provider, providerPayment);
    }
    
    // Register quantum algorithm
    function registerAlgorithm(
        string memory _algorithmHash,
        string memory _name,
        uint256 _minQubits,
        uint256 _estimatedTime,
        uint256 _price,
        bool _isPublic
    ) external {
        require(bytes(_algorithmHash).length > 0, "Algorithm hash cannot be empty");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_minQubits > 0, "Minimum qubits must be greater than 0");
        require(
            quantumAlgorithms[_algorithmHash].creator == address(0),
            "Algorithm already registered"
        );
        
        quantumAlgorithms[_algorithmHash] = QuantumAlgorithm({
            creator: msg.sender,
            name: _name,
            algorithmHash: _algorithmHash,
            minQubits: _minQubits,
            estimatedTime: _estimatedTime,
            usageCount: 0,
            price: _price,
            isPublic: _isPublic
        });
        
        emit AlgorithmRegistered(_algorithmHash, msg.sender, _name, _minQubits);
    }
    
    // Emergency functions
    function disputeJob(uint256 _jobId) 
        external 
        validJob(_jobId) 
        onlyJobClient(_jobId) 
    {
        QuantumJob storage job = quantumJobs[_jobId];
        require(
            job.status == JobStatus.Completed || job.status == JobStatus.Failed,
            "Job must be completed or failed to dispute"
        );
        require(!job.paymentReleased, "Payment already released");
        
        job.status = JobStatus.Disputed;
    }
    
    function cancelJob(uint256 _jobId) 
        external 
        validJob(_jobId) 
        onlyJobClient(_jobId) 
    {
        QuantumJob storage job = quantumJobs[_jobId];
        require(job.status == JobStatus.Pending, "Can only cancel pending jobs");
        
        job.status = JobStatus.Failed;
        
        // Refund payment (minus small cancellation fee)
        uint256 cancellationFee = job.payment / 20; // 5% cancellation fee
        uint256 refundAmount = job.payment - cancellationFee;
        
        payable(job.client).transfer(refundAmount);
    }
    
    // View functions
    function getProvider(address _provider) 
        external 
        view 
        returns (QuantumProvider memory) 
    {
        return quantumProviders[_provider];
    }
    
    function getJob(uint256 _jobId) 
        external 
        view 
        validJob(_jobId) 
        returns (QuantumJob memory) 
    {
        return quantumJobs[_jobId];
    }
    
    function getAvailableProviders(uint256 _minQubits) 
        external 
        view 
        returns (address[] memory) 
    {
        address[] memory availableProviders = new address[](registeredProviders.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < registeredProviders.length; i++) {
            address providerAddr = registeredProviders[i];
            QuantumProvider memory provider = quantumProviders[providerAddr];
            
            if (provider.isActive && provider.qubits >= _minQubits) {
                availableProviders[count] = providerAddr;
                count++;
            }
        }
        
        // Resize array to actual count
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = availableProviders[i];
        }
        
        return result;
    }
    
    function getClientJobs(address _client) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return clientJobs[_client];
    }
    
    function getProviderJobs(address _provider) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return providerJobs[_provider];
    }
    
    function getAlgorithm(string memory _algorithmHash) 
        external 
        view 
        returns (QuantumAlgorithm memory) 
    {
        return quantumAlgorithms[_algorithmHash];
    }
}
