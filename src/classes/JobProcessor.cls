public without sharing class JobProcessor implements Queueable {
	String bulkJobId;
	String[] requestIds;
	String processorName;
	String para1;
	String para2;
	Integer start;

	//public JobProcessor(String bulkJobId, String[] reqIds, Integer start, String processorName) {
	//	this(bulkJobId, reqIds, start, processorName, null, null);
	//}

	public JobProcessor(String bulkJobId, String[] reqIds, Integer start, String processorName, String para1, String para2) {
		this.bulkJobId = bulkJobId;
		this.requestIds = reqIds;
		this.start = start;
		this.processorName = processorName;
		this.para1 = para1;
		this.para2 = para2;
	}

	public void execute(QueueableContext ctx) {
		System.debug(LoggingLevel.DEBUG, 'Enter JobProcessor.execute');
		Type procType = Type.forName(processorName);
		IJobProcessor proc;
		if (procType != null) {
			proc = (IJobProcessor)procType.newInstance();
		}

		if (proc != null) {
			Integer batchSize = proc.getBatchSize();
			Integer stop = (start + batchSize) > requestIds.size() ? requestIds.size() : (start + batchSize);
			String[] batchReqIds = new List<String>();
			for (Integer i = start; i < stop; i++)
				batchReqIds.add(requestIds[i]);

			proc.start(para1, para2);
			// Execute the IJobProcessor.execute() to process the data in batch
			Integer[] batchResps = proc.execute(batchReqIds);

			// Process the batch result
			String batchRespStr;
			for (Integer i = 0; i < batchReqIds.size(); i++) {
				if (batchRespStr == null)
					batchRespStr = batchReqIds[i] + ',' + String.valueOf(batchResps[i]);
				else
					batchRespStr += '|' + batchReqIds[i] + ',' + String.valueOf(batchResps[i]);
			}

			String respStr = [SELECT Response__c FROM Job_Queue__c WHERE Id=:bulkJobId LIMIT 1].Response__c;
			if (String.isEmpty(respStr))
				respStr = batchRespStr;
			else
				respStr += '|' + batchRespStr;

			// Update the response back the bulk Job
			Job_Queue__c job = new Job_Queue__c(
				Id = bulkJobId,
				Response__c = respStr);

			if (requestIds.size() <= stop) {
				job.Status__c = 'Complete';
			}
			
			update job;

			// Chain the Queueable Job if needed
			if (requestIds.size() > stop) { 
				// Still have records to process, stop will be the start for the next queueable job
				System.enqueueJob(new JobProcessor(bulkJobId, requestIds, stop, processorName, para1, para2));
			} else {
				// 
				JobEngine engine = new JobEngine();
				Id schId = engine.dispatch();
			}

		} else {
			System.debug(LoggingLevel.ERROR, processorName + ' class does not exist or implement IJobProcessor interface.');
		}

		System.debug(LoggingLevel.DEBUG, 'Exit JobProcessor.execute');

	}
}