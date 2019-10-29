require 'spec_helper'

describe Workable::Client do
  let(:client) { described_class.new(api_key: 'test', subdomain: 'subdomain') }
  let(:headers){ { 'Authorization' => 'Bearer test', 'User-Agent' => 'Workable Ruby Client' } }

  describe '#new' do
    it 'raises an error on missing api_key / subdomain' do
      expect { described_class.new }.to raise_error(Workable::Errors::InvalidConfiguration)
      expect { described_class.new(api_key: 'key') }.to raise_error(Workable::Errors::InvalidConfiguration)
      expect { described_class.new(subdomain: 'subdomain') }.to raise_error(Workable::Errors::InvalidConfiguration)
    end

    it 'creates new instance when all required arguments are provided' do
      expect(described_class.new(api_key: 'key', subdomain: 'subdomain')).to be_kind_of(described_class)
    end
  end

  describe '#about' do
    it 'returns information about company as a hash' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/')
        .to_return(status: 200, body: about_json_fixture)
      expect(client.about['name']).to eq('Groove Tech')
    end
  end

  describe '#members' do
    it 'returns array of members' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/members')
        .to_return(status: 200, body: members_json_fixture)

      expect(client.members).to be_kind_of(Workable::Collection)
      expect(client.members.data).to be_kind_of(Array)
      expect(client.members.data[0]).to eq(
        'id' => '13e0eb0e',
        'name' => 'Eduardo Vallente',
        'headline' => 'Operations Manager',
        'email' => 'eduardo.vallente@workabledemo.com',
        'role' => 'admin'
      )
    end
  end

  describe '#recruiters' do
    it 'returns array of recruiters' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/recruiters')
        .to_return(status: 200, body: recruiters_json_fixture)

      expect(client.recruiters).to be_kind_of(Array)
      expect(client.recruiters[0]).to eq(
        'id' => '19782abc',
        'name' => 'Nadia Sawahla',
        'email' => 'nadia.sawahla@name.com'
      )
    end
  end

  describe '#stages' do
    it 'returns array of stages' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/stages')
        .to_return(status: 200, body: stages_json_fixture)

      expect(client.stages).to be_kind_of(Array)
      expect(client.stages[0]).to eq(
        'slug' => 'sourced',
        'name' => 'Sourced',
        'kind' => 'sourced',
        'position' => 0
      )
    end
  end

  describe '#jobs' do
    context 'happy path' do
      before do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs')
          .with(headers: headers)
          .to_return(status: 200, body: jobs_index_json_fixture)
      end

      it 'returns collection of posted jobs' do
        expect(client.jobs).to be_kind_of(Workable::Collection)
        expect(client.jobs.data).to be_kind_of(Array)
        expect(client.jobs.data[0]).to include('title' => 'Sales Intern', 'full_title' => 'Sales Intern - US/3/SI')
        expect(client.jobs.data.size).to eq(3)
      end

      it 'includes next page method that returns next collection' do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs?limit=3&since_id=2700d6df')
          .with(headers: headers)
          .to_return(status: 200, body: jobs_index_json_fixture)

        jobs = client.jobs.fetch_next_page
        expect(jobs).to be_kind_of(Workable::Collection)
        expect(client.jobs.data).to be_kind_of(Array)
      end
    end

    context 'sad path' do
      it 'raises exception on not authorized error (401)' do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs')
          .to_return(status: 401, body: '{"error":"Not authorized"}')

        expect { client.jobs }.to raise_error(Workable::Errors::NotAuthorized)
      end

      it 'raises exception when status code differs from 200' do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs')
          .to_return(status: 500, body: '')

        expect { client.jobs }.to raise_error(Workable::Errors::InvalidResponse)
      end
    end
  end

  describe '#job_details' do
    it 'returns details of given job' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/03FF356C8B')
        .to_return(status: 200, body: job_json_fixture)

      expect(client.job_details('03FF356C8B')).to be_kind_of(Hash)
    end

    it 'raises an exception when job is not found' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/invalid')
        .to_return(status: 404, body: '{"error":"Not found"}')

      expect { client.job_details('invalid') }.to raise_error(Workable::Errors::NotFound)
    end
  end

  describe '#job_questions' do
    it 'returns questions for given job' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/03FF356C8B/questions')
        .to_return(status: 200, body: job_questions_json_fixture)

      questions = client.job_questions('03FF356C8B')
      expect(questions).to be_kind_of(Array)
      expect(questions[0]['body']).to eq('Explain one aspect of this role you believe you will excel at.')
    end
  end

  describe '#job_application_form' do
    it 'returns application form for given job' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/03FF356C8B/application_form')
        .to_return(status: 200, body: job_application_form_fixture)

      form = client.job_application_form('03FF356C8B')
      expect(form).to be_kind_of(Hash)
      expect(form.has_key?('questions')).to eq true
      expect(form['form_fields'][0]).to eq({
        'key' => 'phone',
        'label' => 'Phone',
        'type' => 'string',
        'required' => true
      })

    end
  end

  describe '#job_members' do
    it "returns array of job's members" do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/job_slug/members')
        .to_return(status: 200, body: members_json_fixture)

      expect(client.job_members('job_slug')).to be_kind_of(Array)
      expect(client.job_members('job_slug')[0]).to eq(
        'id' => '13e0eb0e',
        'name' => 'Eduardo Vallente',
        'headline' => 'Operations Manager',
        'email' => 'eduardo.vallente@workabledemo.com',
        'role' => 'admin'
      )
    end
  end

  describe 'job_recruiters' do
    it "returns array of job's recruiters" do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/job_slug/recruiters')
        .to_return(status: 200, body: recruiters_json_fixture)

      expect(client.job_recruiters('job_slug')).to be_kind_of(Array)
      expect(client.job_recruiters('job_slug')[0]).to eq(
        'id' => '19782abc',
        'name' => 'Nadia Sawahla',
        'email' => 'nadia.sawahla@name.com'
      )
    end
  end

  describe '#job_candidates' do
    context 'happy path' do
      let(:candidates){ client.job_candidates('03FF356C8B') }
      before do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/03FF356C8B/candidates')
          .to_return(status: 200, body: job_candidates_json_fixture)
      end

      it 'returns collection of candidates for given job' do
        expect(candidates).to be_kind_of(Workable::Collection)
        expect(candidates.data[0]['name']).to eq('Lakita Marrero')
      end

      it 'includes next page method that returns next collection' do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/candidates?limit=3&since_id=2700d6df')
          .with(headers: headers)
          .to_return(status: 200, body: job_candidates_json_fixture)

        next_candidates = candidates.fetch_next_page
        expect(next_candidates).to be_kind_of(Workable::Collection)
        expect(next_candidates.data).to be_kind_of(Array)
      end
    end

    context 'sad path' do
      it 'raises exception on to long requests' do
        stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/03FF356C8B/candidates')
          .to_return(status: 503, body: '{"error":"Not authorized"}')

        expect { client.job_candidates('03FF356C8B') }.to raise_error(Workable::Errors::RequestToLong)
      end
    end
  end

  describe '#job_candidate' do
    it 'returns detailed info about given candidate' do
      stub_request(:get, 'https://subdomain.workable.com/spi/v3/jobs/job-slug/candidates/some-id')
        .to_return(status: 200, body: job_candidate_json_fixture)

      expect(client.job_candidate('job-slug', 'some-id')['name']).to eq('Cindy Sawyers')
    end
  end

  describe '#create_job_candidate' do
    it 'POSTs requests and parses response' do
      stub_request(:post, 'https://subdomain.workable.com/spi/v3/jobs/slug/candidates')
        .with(body: new_candidate_hash_fixture.to_json)
        .to_return(status: 200, body: new_candidate_response_json_fixture)

      candidate = client.create_job_candidate(new_candidate_hash_fixture, 'slug')
      expect(candidate['id']).to eq('3fc9a80f')
    end
  end

  describe '#create_comment' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:comment_text) { "Hire this person!" }
    let(:body) do
      {
        member_id: member_id,
        comment: {
          body: comment_text,
          policy: [],
          attachment: nil
        }
      }
    end

    it 'submits POST request' do
      stub = stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/comments')
        .with(body: body.to_json)

      client.create_comment(candidate_id, member_id, comment_text)
      expect(stub).to have_been_requested.once
    end
  end

  describe '#disqualify' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:reason) { 'Lacks experience.' }
    let(:body) do
      {
        member_id: member_id,
        disqualification_reason: reason
      }
    end

    it 'submits POST request' do
      stub = stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/disqualify')
        .with(body: body.to_json)

      client.disqualify(candidate_id, member_id, reason)
      expect(stub).to have_been_requested.once
    end
  end

  describe '#revert' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:body) do
      { member_id: member_id }
    end

    it 'submits POST request' do
      stub = stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/revert')
        .with(body: body.to_json)

      client.revert(candidate_id, member_id)
      expect(stub).to have_been_requested.once
    end
  end

  describe '#copy' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:shortcode) { 'GROOV005' }
    let(:stage) { 'applied' }
    let(:body) do
      {
        member_id: member_id,
        target_job_shortcode: shortcode,
        target_stage: stage
      }
    end

    it 'POSTs requests and parses response' do
      stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/copy')
        .with(body: body.to_json)
        .to_return(status: 201, body: copy_candidate_response_json_fixture)

      candidate = client.copy(candidate_id, member_id, shortcode, stage)
      expect(candidate['id']).to eq(candidate_id)
    end
  end

  describe '#relocate' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:shortcode) { 'GROOV005' }
    let(:stage) { 'applied' }
    let(:body) do
      {
        member_id: member_id,
        target_job_shortcode: shortcode,
        target_stage: stage
      }
    end

    it 'POSTs requests and parses response' do
      stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/relocate')
        .with(body: body.to_json)
        .to_return(status: 201, body: relocate_candidate_response_json_fixture)

      candidate = client.relocate(candidate_id, member_id, shortcode, stage)
      expect(candidate['id']).to eq(candidate_id)
    end
  end

  describe '#move' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:stage ) { 'applied' }
    let(:body) do
      {
        member_id: member_id,
        target_stage: stage
      }
    end

    it 'submits POST request' do
      stub = stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/move')
        .with(body: body.to_json)

      client.move(candidate_id, member_id, stage)
      expect(stub).to have_been_requested.once
    end
  end

  describe '#create_rating' do
    let(:candidate_id) { '123456' }
    let(:member_id) { '314' }
    let(:comment) { 'Good, I guess' }
    let(:score) { 'positive' }
    let(:body) do
      {
        member_id: member_id,
        comment: comment,
        score: score
      }
    end

    it 'submits POST request' do
      stub = stub_request(:post, 'https://subdomain.workable.com/spi/v3/candidates/123456/ratings')
        .with(body: body.to_json)

      client.create_rating(candidate_id, member_id, comment, score)
      expect(stub).to have_been_requested.once
    end
  end
end
