public with sharing class JobEngine {
	public enum Priority { High, Medium, Low }

	public JobEngine() {
		
	}

	public Id addJob(Priority p, String processorName, List<String> recs) {
		Job_Queue__c job = new Job_Queue__c(
			Priority__c = getPriorityVal(p),
			Processor__c = processorName,
			Request__c = String.join(recs, ','),
			Status__c = 'Ready'
			);

		insert job;

		return job.Id;
	}

	Integer getPriorityVal(Priority p) {
		if (p == Priority.High) return 2;
		else if (p == Priority.Medium) return 1;
		else return 0;
	}
}