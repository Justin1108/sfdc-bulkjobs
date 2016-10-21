public interface IJobProcessor {
	Integer getBatchSize();
	Integer[] execute(String[] requestIds);
}