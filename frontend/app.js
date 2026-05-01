const tokenAbi = [
    "function balanceOf(address account) view returns (uint256)",
    "function delegates(address account) view returns (address)",
    "function getVotes(address account) view returns (uint256)",
    "function delegate(address delegatee) returns (bool)"
];

const governorAbi = [
    "function state(uint256 proposalId) view returns (uint8)",
    "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes,uint256 forVotes,uint256 abstainVotes)",
    "function castVote(uint256 proposalId,uint8 support) returns (uint256)"
];

const proposalStates = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];

let provider;
let signer;
let accountAddress;
let tokenContract;
let governorContract;

const elements = {
    connectWalletButton: document.querySelector("#connectWalletButton"),
    saveContractsButton: document.querySelector("#saveContractsButton"),
    delegateVotesButton: document.querySelector("#delegateVotesButton"),
    loadProposalButton: document.querySelector("#loadProposalButton"),
    tokenAddressInput: document.querySelector("#tokenAddressInput"),
    governorAddressInput: document.querySelector("#governorAddressInput"),
    delegateAddressInput: document.querySelector("#delegateAddressInput"),
    proposalIdInput: document.querySelector("#proposalIdInput"),
    accountValue: document.querySelector("#accountValue"),
    tokenBalanceValue: document.querySelector("#tokenBalanceValue"),
    votingPowerValue: document.querySelector("#votingPowerValue"),
    delegateValue: document.querySelector("#delegateValue"),
    proposalList: document.querySelector("#proposalList"),
    activityLog: document.querySelector("#activityLog")
};

elements.tokenAddressInput.value = localStorage.getItem("daoTokenAddress") || "";
elements.governorAddressInput.value = localStorage.getItem("daoGovernorAddress") || "";

elements.connectWalletButton.addEventListener("click", connectWallet);
elements.saveContractsButton.addEventListener("click", saveContracts);
elements.delegateVotesButton.addEventListener("click", delegateVotes);
elements.loadProposalButton.addEventListener("click", loadProposal);

document.querySelectorAll("[data-support]").forEach((button) => {
    button.addEventListener("click", () => castVote(Number(button.dataset.support)));
});

function logActivity(message) {
    elements.activityLog.textContent = `${new Date().toLocaleTimeString()} ${message}\n${elements.activityLog.textContent}`;
}

async function connectWallet() {
    if (!window.ethereum) {
        logActivity("MetaMask is not available.");
        return;
    }

    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();
    accountAddress = await signer.getAddress();
    elements.accountValue.textContent = accountAddress;
    elements.connectWalletButton.textContent = "Wallet Connected";

    loadContracts();
    await refreshWalletData();
}

function saveContracts() {
    localStorage.setItem("daoTokenAddress", elements.tokenAddressInput.value.trim());
    localStorage.setItem("daoGovernorAddress", elements.governorAddressInput.value.trim());
    loadContracts();
    logActivity("Contract addresses saved.");
}

function loadContracts() {
    if (!signer) {
        return;
    }

    const tokenAddress = elements.tokenAddressInput.value.trim();
    const governorAddress = elements.governorAddressInput.value.trim();

    if (ethers.isAddress(tokenAddress)) {
        tokenContract = new ethers.Contract(tokenAddress, tokenAbi, signer);
    }

    if (ethers.isAddress(governorAddress)) {
        governorContract = new ethers.Contract(governorAddress, governorAbi, signer);
    }
}

async function refreshWalletData() {
    if (!tokenContract || !accountAddress) {
        return;
    }

    const [balance, votingPower, delegateAddress] = await Promise.all([
        tokenContract.balanceOf(accountAddress),
        tokenContract.getVotes(accountAddress),
        tokenContract.delegates(accountAddress)
    ]);

    elements.tokenBalanceValue.textContent = `${ethers.formatEther(balance)} GOV`;
    elements.votingPowerValue.textContent = `${ethers.formatEther(votingPower)} GOV`;
    elements.delegateValue.textContent = delegateAddress;
}

async function delegateVotes() {
    const delegateAddress = elements.delegateAddressInput.value.trim();

    if (!tokenContract || !ethers.isAddress(delegateAddress)) {
        logActivity("Enter a valid delegate address.");
        return;
    }

    const transaction = await tokenContract.delegate(delegateAddress);
    logActivity(`Delegation submitted: ${transaction.hash}`);
    await transaction.wait();
    logActivity("Delegation confirmed.");
    await refreshWalletData();
}

async function loadProposal() {
    const proposalId = elements.proposalIdInput.value.trim();

    if (!governorContract || proposalId.length === 0) {
        logActivity("Enter a proposal ID.");
        return;
    }

    const trackedProposalIds = new Set(JSON.parse(localStorage.getItem("trackedProposalIds") || "[]"));
    trackedProposalIds.add(proposalId);
    localStorage.setItem("trackedProposalIds", JSON.stringify([...trackedProposalIds]));
    await renderProposals();
}

async function renderProposals() {
    if (!governorContract) {
        return;
    }

    const trackedProposalIds = JSON.parse(localStorage.getItem("trackedProposalIds") || "[]");
    elements.proposalList.innerHTML = "";

    for (const proposalId of trackedProposalIds) {
        const [stateIndex, votes] = await Promise.all([
            governorContract.state(proposalId),
            governorContract.proposalVotes(proposalId)
        ]);

        const row = document.createElement("div");
        row.className = "proposal-row";
        row.innerHTML = `
            <strong>${proposalId}</strong>
            <span>${proposalStates[Number(stateIndex)]}</span>
            <span>For ${ethers.formatEther(votes.forVotes)}</span>
            <span>Against ${ethers.formatEther(votes.againstVotes)}</span>
            <span>Abstain ${ethers.formatEther(votes.abstainVotes)}</span>
        `;
        elements.proposalList.appendChild(row);
    }
}

async function castVote(support) {
    const proposalId = elements.proposalIdInput.value.trim();

    if (!governorContract || proposalId.length === 0) {
        logActivity("Enter a proposal ID before voting.");
        return;
    }

    const transaction = await governorContract.castVote(proposalId, support);
    logActivity(`Vote submitted: ${transaction.hash}`);
    await transaction.wait();
    logActivity("Vote confirmed.");
    await renderProposals();
}
