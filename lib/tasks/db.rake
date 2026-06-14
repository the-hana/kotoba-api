namespace :db do
  # 初回デプロイ時のみシードを実行する
  # Wordテーブルが空の場合のみ実行し、データが存在する場合はスキップする
  task seed_if_empty: :environment do
    if Word.count.zero?
      Rake::Task["db:seed"].invoke
    else
      puts "シードデータが既に存在するためスキップします (#{Word.count} words)"
    end
  end
end
