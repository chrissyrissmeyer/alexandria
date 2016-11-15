class AudioRecordingPresenter < CurationConcerns::WorkShowPresenter
  delegate(
    :accession_number,
    :alternative,
    :ark,
    :citation,
    :copyright_status,
    :extent,
    :form_of_work,
    :fulltext_link,
    :issue_number,
    :issued,
    :license,
    :location,
    :matrix_number,
    :notes,
    :place_of_publication,
    :restrictions,
    :rights_holder,
    :sub_location,
    :table_of_contents,
    to: :solr_document
  )
end
