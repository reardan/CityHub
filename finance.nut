class Finance {
	function Balance() {
		return AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	}

	function UnusedLoan() {
		return AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount();
	}

	function Usable() {
		return this.Balance() + this.UnusedLoan();
	}

	function ProjectCap() {
		local cap = this.Usable() * 70 / 100;
		if (cap < 0) cap = 0;
		return cap;
	}

	function EnsureMoney(need) {
		if (need <= 0) return true;
		if (this.Balance() >= need) return true;
		local extra = need - this.Balance();
		local target = AICompany.GetLoanAmount() + extra;
		local max_loan = AICompany.GetMaxLoanAmount();
		if (target > max_loan) target = max_loan;
		AICompany.SetMinimumLoanAmount(target);
		if (this.Balance() >= need) return true;
		AIController.Sleep(20);
		AICompany.SetMinimumLoanAmount(target);
		return this.Balance() >= need;
	}

	function MaybeRepay() {
		local income = AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF, 1);
		if (income <= 0) return;
		local interval = AICompany.GetLoanInterval();
		local loan = AICompany.GetLoanAmount();
		if (loan <= 0) return;
		local cash = this.Balance();
		local repay = cash / 2;
		repay = repay - (repay % interval);
		if (repay <= 0) return;
		if (repay > loan) repay = loan;
		if (loan - repay + cash < 0) return;
		AICompany.SetLoanAmount(loan - repay);
	}
}
